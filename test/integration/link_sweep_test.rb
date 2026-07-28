require "test_helper"

# Follows every internal link on the reachable pages and fails on any that
# errors. Catches routes renamed out from under a view, and dead footer links.
class LinkSweepTest < ActionDispatch::IntegrationTest
  # Links that legitimately do not render a page for a GET.
  SKIP = %r{\A(#|mailto:|tel:|javascript:|https?://)}

  setup do
    @host = create(:user, :host, stripe_account_id: "acct_x", stripe_charges_enabled: true)
    @property = create(:property, user: @host, title: "Sweep House")
    @guest = create(:user, :business_verified)
    @admin = create(:user, :admin)
    @booking = create(:booking, property: @property, user: @guest, status: :confirmed,
                                check_in: Date.current + 20, check_out: Date.current + 22)
  end

  def internal_links(body)
    body.scan(/<a[^>]+href="([^"]+)"/).flatten
        .reject { |href| href.blank? || href.match?(SKIP) }
        .map { |href| href.split("#").first }
        .compact_blank
        .uniq
  end

  # Visits `pages`, then every internal link found on them, and reports any that
  # come back 404 or 5xx.
  def sweep(pages)
    broken = []
    seen = Set.new

    pages.each do |page|
      get page
      assert_includes 200..399, response.status, "#{page} itself returned #{response.status}"
      next unless response.status == 200

      internal_links(response.body).each do |link|
        next unless seen.add?(link)

        begin
          get link
          broken << "#{link} -> #{response.status} (linked from #{page})" if response.status == 404 || response.status >= 500
        rescue ActionController::RoutingError, ActionController::UrlGenerationError => e
          broken << "#{link} -> #{e.class} (linked from #{page})"
        end
      end
    end

    assert_empty broken, "broken links:\n  #{broken.join("\n  ")}"
  end

  test "public pages have no broken links" do
    sweep [
      root_path, properties_path, property_path(@property), about_path, contact_path,
      how_it_works_path, help_page_path, safety_path, privacy_path, terms_path,
      cookies_policy_path, new_user_session_path, new_user_registration_path,
      new_user_password_path
    ]
  end

  test "a signed-in guest's pages have no broken links" do
    sign_in @guest
    sweep [ root_path, bookings_path, booking_path(@booking), conversations_path,
            properties_path(favorites: true), new_business_verification_path ]
  end

  test "a host's pages have no broken links" do
    sign_in @host
    sweep [ host_root_path, host_bookings_path, host_booking_path(@booking),
            host_properties_path, host_calendar_path, host_conversations_path,
            host_stripe_account_path, new_host_application_path ]
  end

  test "an admin's pages have no broken links" do
    sign_in @admin
    sweep [ admin_root_path, admin_users_path, admin_properties_path,
            admin_bookings_path, admin_booking_path(@booking),
            admin_host_applications_path, admin_reviews_path,
            admin_contact_submissions_path ]
  end
end
