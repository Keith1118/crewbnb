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

  # Bookings are closed pre-launch, so the booking card offers an enquiry
  # instead. It used to show a dead "Bookings opening soon" button, which gave a
  # ready buyer nothing to do.
  test "a listing offers an enquiry while bookings are closed" do
    property = create(:property, status: :published)

    get property_path(property)

    assert_response :success
    assert_select "a[href=?]", root_path(anchor: "enquiry"), text: "Enquire"
    assert_select "[aria-disabled]", count: 0
  end

  test "a listing links from the header to its map" do
    property = create(:property, status: :published, city: "Blessington", country: "Ireland")

    get property_path(property)

    assert_response :success
    assert_select "a[href=?]", "#location", text: /View on map/
    assert_select "section#location"
  end

  # Search Console rejects a relative image or a "4:00 PM" time as the wrong
  # value type, and drops the rich result for the page.
  test "a listing's structured data is valid and uses absolute URLs" do
    property = create(:property, status: :published,
                                 check_in_time: "4:00 PM", check_out_time: "11:00 AM")

    get property_path(property)

    # Parse exactly what is served. Entities are NOT decoded inside a script
    # tag, so unescaping here would hide the very bug this guards against:
    # ERB once turned every quote into &quot; and Google refused the page.
    scripts = css_select("script[type='application/ld+json']").map(&:text)
    scripts.each { |raw| assert_no_match(/&quot;|&#39;|&amp;quot;/, raw) }
    json = scripts.map { |raw| JSON.parse(raw) }
    lodging = json.find { |d| d["@type"] == "LodgingBusiness" }

    assert lodging, "no LodgingBusiness block"
    assert_equal "16:00:00", lodging["checkinTime"]
    assert_equal "11:00:00", lodging["checkoutTime"]
    assert_match %r{\Ahttps?://}, lodging["url"]
    assert_match %r{\Ahttps?://}, lodging["image"] if lodging["image"]
  end

  # A template comment that mentioned an output tag closed itself early and
  # printed the rest of the comment at the top of every listing.
  test "no template comment leaks onto a listing page" do
    property = create(:property, status: :published)

    get property_path(property)

    assert_no_match(/ERB would|%>/, @response.body)
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

  test "a town page lists that town's published stays and nothing else" do
    create(:property, status: :published, city: "Edenderry", title: "Edenderry Twin")
    create(:property, :draft, city: "Edenderry", title: "Edenderry Draft")
    create(:property, status: :published, city: "Blessington", title: "Lakeside House")

    get town_path("edenderry")

    assert_response :success
    assert_select "h1", text: /Contractor accommodation in Edenderry, Co\. Offaly/
    assert_select "title", text: /Contractor Accommodation in Edenderry/
    assert_match "Edenderry Twin", @response.body
    assert_no_match "Edenderry Draft", @response.body
    assert_no_match "Lakeside House", @response.body
    # Links across to the other town that has listings.
    assert_select "a[href=?]", town_path("blessington")
  end

  test "a town page's structured data parses" do
    create(:property, status: :published, city: "Edenderry")

    get town_path("edenderry")

    types = css_select("script[type='application/ld+json']").map { |s| JSON.parse(s.text)["@type"] }
    assert_includes types, "BreadcrumbList"
    assert_includes types, "ItemList"
  end

  # An empty town page is the thin kind Google penalises; an unknown slug is a
  # typo. Neither should render.
  test "a town with no live listings, or no such town, is a 404" do
    create(:property, :draft, city: "Blessington")

    get town_path("blessington")
    assert_response :not_found

    get town_path("atlantis")
    assert_response :not_found
  end

  # Ten listings are titled "Double Room" or "Twin Room"; the town and the
  # category are what stop them all having the same <title>.
  test "a listing's title names the town and the category" do
    property = create(:property, status: :published, title: "Double Room", city: "Edenderry")

    get property_path(property)

    assert_select "title", text: "Double Room — Contractor Accommodation in Edenderry | Crewbase"
    assert_select "nav[aria-label=Breadcrumb] a[href=?]", town_path("edenderry")
    crumbs = css_select("script[type='application/ld+json']").map { |s| JSON.parse(s.text) }
                                                             .find { |d| d["@type"] == "BreadcrumbList" }
    assert_equal [ "Crewbase", "Contractor accommodation", "Edenderry", "Double Room" ],
                 crumbs["itemListElement"].map { |i| i["name"] }
  end

  test "the home page and sitemap link to towns with listings only" do
    create(:property, status: :published, city: "Edenderry")

    get root_path
    assert_select "a[href=?]", town_path("edenderry")
    assert_select "a[href=?]", town_path("blessington"), count: 0

    get sitemap_path
    assert_match town_url("edenderry"), @response.body
    assert_no_match town_url("blessington"), @response.body
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
