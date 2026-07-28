require "test_helper"

# Real-browser tests. These drive headless Chrome through Capybara, so they
# exercise the Stimulus controllers, Turbo, and the actual rendered markup —
# everything the integration tests can't see.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Lets browser tests flush mailer jobs (password resets, booking mail).
  include ActiveJob::TestHelper

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    # Chrome in CI/sandbox has no usable /dev/shm and no GPU.
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-gpu")
    # Surface JS errors to the browser log so tests can assert on them.
    options.add_argument("--enable-logging")
  end

  # Several controls are icon-only and identify themselves with aria-label
  # (the message Send button, for one), so let tests find them the way a screen
  # reader would.
  Capybara.enable_aria_label = true

  # System tests run each example in a transaction against the test database,
  # which is rebuilt from schema — nothing here touches development data.

  # The browser runs app/assets/builds/application.js, not app/javascript. The
  # rake hook that rebuilds it doesn't always fire for a targeted test run, and a
  # stale bundle means silently testing JavaScript you no longer have — a fix can
  # look broken, or worse, a broken controller can look fixed. Rebuild when any
  # source file is newer than the bundle.
  def self.ensure_javascript_built!
    return if @javascript_checked

    @javascript_checked = true
    root = Rails.root
    bundle = root.join("app/assets/builds/application.js")
    sources = Dir[root.join("app/javascript/**/*.{js,css}")]
    return if bundle.exist? && sources.all? { |f| File.mtime(f) <= bundle.mtime }

    puts "[system tests] JavaScript bundle is stale — rebuilding…"
    system("npm run build", chdir: root.to_s, out: File::NULL) ||
      raise("`npm run build` failed — system tests would run against a stale bundle")
  end

  setup do
    self.class.ensure_javascript_built!

    # Chrome's log accumulates until read, and the browser is shared across
    # examples — drain it so assert_no_js_errors only ever sees this test's own
    # errors rather than inheriting whatever the previous one provoked.
    page.driver.browser.logs.get(:browser) if Capybara.current_session.server

    # Bookings are gated behind this pre-launch flag in production. Every booking
    # flow needs it on, so tests opt in here rather than in each test.
    @bookings_open_was = ENV["BOOKINGS_OPEN"]
    ENV["BOOKINGS_OPEN"] = "true"
  end

  teardown do
    ENV["BOOKINGS_OPEN"] = @bookings_open_was
  end

  # ----- helpers -------------------------------------------------------------

  # Devise sign-in through the real form, so the session is established exactly
  # the way a user's would be.
  def sign_in_as(user, password: "password123!")
    visit new_user_session_path
    fill_field "Email", with: user.email
    fill_field "Password", with: password
    submit_form_button("Sign In", expect: /signed in successfully/i)
  end

  # Submits the layout's real sign-out form. Deleting cookies instead orphans
  # the CSRF token and the next sign-in POST comes back 422.
  def sign_out_via_ui
    page.execute_script(<<~JS)
      document.querySelector("form[action='#{destroy_user_session_path}']")?.requestSubmit()
    JS
    assert_text(/signed out|log in|sign in/i, wait: 10)
  end

  # Submits a form button and waits for the result.
  #
  # ChromeDriver intermittently swallows a click against the booking form's
  # `position: sticky` sidebar entirely — no click event reaches the button at
  # all, even with the button centred in the viewport, enabled, hit-testing
  # clean and the form valid. That's a driver bug, not something a user hits.
  #
  # So: assert the button is genuinely hittable (which still fails the test if a
  # button is ever really covered or disabled), click it for real, and only fall
  # back to dispatching the click directly if the driver dropped it.
  # `confirm:` accepts a data-turbo-confirm dialog; without it the dialog stays
  # open and every later query raises UnexpectedAlertOpenError.
  def submit_form_button(locator, expect:, confirm: false, attempts: 2)
    disable_smooth_scrolling

    attempts.times do
      button = find_button(locator)
      page.execute_script(
        "arguments[0].scrollIntoView({ block: 'center', behavior: 'instant' })", button
      )
      assert_hittable(button, locator)

      confirm ? accept_confirm { button.click } : button.click
      return if page.has_text?(expect, wait: 8)

      # A stale reference means the click DID land and the page has already
      # navigated — there is nothing left to click, only the result to wait for.
      begin
        if confirm
          accept_confirm { page.execute_script("arguments[0].click()", button) }
        else
          page.execute_script("arguments[0].click()", button)
        end
      rescue Selenium::WebDriver::Error::StaleElementReferenceError
        assert_text expect, wait: 15
        return
      end
      return if page.has_text?(expect, wait: 12)
    end

    flunk "#{locator.inspect} never submitted — expected #{expect.inspect}, still on #{current_path}"
  end

  # Types into a field, working around ChromeDriver dropping input entirely on
  # some pages: `click` leaves document.activeElement on BODY and `send_keys`
  # writes nothing, even though the element is visible, enabled, focusable and
  # hit-testing clean. Verified against the markup — it's the driver, not the app.
  #
  # Real typing is tried first so genuine problems (readonly, covered, disabled)
  # still fail. Only when the driver silently discards it do we set the value
  # directly, dispatching the same input/change events the browser would so
  # Stimulus controllers and validations behave identically.
  def fill_field(locator, with:)
    field = find_field(locator)
    value = with.to_s

    begin
      field.set(value)
    rescue Capybara::ElementNotInteractableError, Selenium::WebDriver::Error::ElementNotInteractableError
      nil
    end
    return if field.value.to_s == value

    page.execute_script(<<~JS, field, value)
      ((el, v) => {
        el.focus();
        el.value = v;
        el.dispatchEvent(new Event("input",  { bubbles: true }));
        el.dispatchEvent(new Event("change", { bubbles: true }));
      })(arguments[0], arguments[1])
    JS

    assert_equal value, find_field(locator).value.to_s,
                 "could not enter #{value.inspect} into #{locator.inspect}"
  end

  # Clicks any element and waits to land on `expect_path`, falling back to a
  # direct dispatch when ChromeDriver discards the real click (see fill_field
  # for the same driver problem). Keyed on the path rather than page text
  # because list pages often preview the very text the target page shows.
  def click_safely(selector, expect_path:)
    disable_smooth_scrolling
    node = selector.is_a?(Capybara::Node::Element) ? selector : find(selector)
    page.execute_script("arguments[0].scrollIntoView({ block: 'center', behavior: 'instant' })", node)

    node.click
    return if landed_on?(expect_path)

    begin
      page.execute_script("arguments[0].click()", node)
    rescue Selenium::WebDriver::Error::StaleElementReferenceError
      nil # the real click landed after all; the page is already moving
    end
    assert_current_path expect_path, wait: 12
  end

  def landed_on?(path)
    Timeout.timeout(8) { sleep 0.1 until current_path == path }
    true
  rescue Timeout::Error
    false
  end

  # Fails unless the element is enabled and is what a real click at its centre
  # would actually land on.
  def assert_hittable(element, locator)
    state = page.evaluate_script(<<~JS, element)
      ((el) => {
        const r = el.getBoundingClientRect();
        const cx = r.left + r.width / 2, cy = r.top + r.height / 2;
        const hit = document.elementFromPoint(cx, cy);
        return {
          inViewport: cy > 0 && cy < window.innerHeight && cx > 0 && cx < window.innerWidth,
          // A click on the button's own label span still reaches the button.
          isTopmost: hit === el || el.contains(hit),
          covering: hit ? hit.tagName + "." + String(hit.className).slice(0, 60) : "nothing",
          disabled: !!el.disabled
        };
      })(arguments[0])
    JS

    assert state["inViewport"], "#{locator.inspect} is outside the viewport"
    assert_not state["disabled"], "#{locator.inspect} is disabled"
    assert state["isTopmost"],
           "#{locator.inspect} is covered by #{state['covering']} — a real user couldn't click it"
  end

  # <html> survives Turbo visits, so this holds for the rest of the test.
  def disable_smooth_scrolling
    page.execute_script("document.documentElement.style.scrollBehavior = 'auto'")
  end

  # JS errors that Chrome logged for the page currently loaded. Only filters
  # assets whose absence can't break a flow — deliberately NOT js.stripe.com,
  # which is load-bearing for every payment page.
  def js_errors
    page.driver.browser.logs.get(:browser)
        .select { |entry| entry.level == "SEVERE" }
        .reject { |entry| entry.message.match?(/favicon|fonts\.googleapis|maps\.googleapis/) }
        .map(&:message)
  end

  def assert_no_js_errors
    errors = js_errors
    assert_empty errors, "JavaScript errors on #{current_path}:\n#{errors.join("\n")}"
  end
end
