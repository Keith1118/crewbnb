xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
  # Only what the site links to now. /about, /how-it-works, /help and /safety
  # still respond, but while this is an email-enquiry landing page they aren't
  # worth indexing — and some still carry claims the listings no longer make.
  #
  # /properties is in: it's the hub every listing hangs off, and the page that
  # should rank for the category rather than for one house.
  static_pages = [
    root_url, properties_url, contact_url, privacy_url, terms_url, cookies_policy_url
  ]

  static_pages.each do |url|
    xml.url do
      xml.loc url
      xml.changefreq "weekly"
    end
  end

  @properties.each do |property|
    xml.url do
      xml.loc property_url(property)
      xml.lastmod property.updated_at.iso8601
      xml.changefreq "daily"
    end
  end
end
