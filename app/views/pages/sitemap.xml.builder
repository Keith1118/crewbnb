xml.instruct! :xml, version: "1.0", encoding: "UTF-8"
xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
  static_pages = [
    root_url, properties_url, how_it_works_url, about_url, contact_url,
    help_page_url, safety_url, privacy_url, terms_url, cookies_policy_url
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
