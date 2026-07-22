require "test_helper"

# Everything a signed-out visitor can see. These pages carry the SEO and the
# first impression, so a 500 here is a launch-blocker.
class PublicBrowsingTest < ActionDispatch::IntegrationTest
  test "the marketing pages all render for a signed-out visitor" do
    [ root_path, about_path, how_it_works_path, help_page_path, safety_path,
      privacy_path, terms_path, cookies_policy_path, contact_path ].each do |path|
      get path
      assert_response :success, "expected 200 for #{path}"
    end
  end

  test "the properties index renders and lists published stays only" do
    live = create(:property, status: :published, title: "Live House")
    create(:property, :draft, title: "Hidden Draft")

    get properties_path

    assert_response :success
    assert_match "Live House", @response.body
    assert_no_match "Hidden Draft", @response.body
    _ = live
  end

  test "a listing page renders for a signed-out visitor" do
    property = create(:property, status: :published)

    get property_path(property)

    assert_response :success
  end

  test "an archived listing is not publicly bookable via new" do
    property = create(:property, status: :archived)
    sign_in create(:user, :business_verified)

    with_bookings_open do
      # Property.published.find is used, so an archived listing 404s the booking form.
      get new_property_booking_path(property)
      assert_response :not_found
    end
  end

  test "the sitemap renders as XML" do
    create(:property, status: :published)

    get sitemap_path

    assert_response :success
    assert_match "urlset", @response.body
  end

  test "full-text search by town narrows the results" do
    create(:property, status: :published, city: "Edenderry", title: "Edenderry Digs")
    create(:property, status: :published, city: "Killarney", title: "Killarney Lodge")

    get properties_path, params: { query: "Edenderry" }

    assert_response :success
    assert_match "Edenderry Digs", @response.body
    assert_no_match "Killarney Lodge", @response.body
  end

  test "filtering by party size excludes listings that are too small" do
    create(:property, status: :published, title: "Sleeps Two", max_guests: 2)
    create(:property, status: :published, title: "Sleeps Eight", max_guests: 8)

    get properties_path, params: { guests: 6 }

    assert_response :success
    assert_match "Sleeps Eight", @response.body
    assert_no_match "Sleeps Two", @response.body
  end

  private

  def with_bookings_open
    previous = ENV["BOOKINGS_OPEN"]
    ENV["BOOKINGS_OPEN"] = "true"
    yield
  ensure
    ENV["BOOKINGS_OPEN"] = previous
  end
end
