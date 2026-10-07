module ApplicationHelper
  include Pagy::Frontend

  def meta_description(text = nil)
    if text
      content_for(:meta_description, text)
    else
      content_for?(:meta_description) ? content_for(:meta_description) : "Crewbase — contractor accommodation for working crews of every kind: construction, film, engineering, business teams and more. Weekday pricing, automatic invoices, stays built for people who travel for work."
    end
  end

  # The address visitors are told to write to. Our own mail is delivered
  # elsewhere — see config.x.admin_inbox.
  def contact_email
    Rails.application.config.x.contact_email
  end

  def meta_image
    content_for?(:meta_image) ? content_for(:meta_image) : "#{request.base_url}/icon.png"
  end

  # The JSON-LD describing a listing, as a Hash.
  #
  # Built here rather than written out by hand in the template. ERB escapes
  # what <%= %> prints, so "<%= title.to_json %>" inside a <script> emitted
  # &quot; instead of " — and entities are NOT decoded inside a script tag, so
  # Google received invalid JSON and dropped the page's rich result. Render it
  # with `raw json_escape(...)`, never a bare <%= %>.
  def lodging_structured_data(property)
    data = {
      "@context" => "https://schema.org",
      "@type" => "LodgingBusiness",
      "name" => property.title,
      "description" => property.description.to_s.truncate(300),
      "url" => property_url(property),
      "address" => {
        "@type" => "PostalAddress",
        "streetAddress" => property.address.presence,
        "addressLocality" => property.city,
        "addressCountry" => property.country
      }.compact
    }

    data["image"] = rails_blob_url(property.images.first) if property.images.attached?

    if property.latitude.present? && property.longitude.present?
      data["geo"] = {
        "@type" => "GeoCoordinates",
        "latitude" => property.latitude.to_f,
        "longitude" => property.longitude.to_f
      }
    end

    if property.average_rating && property.reviews.any?
      data["aggregateRating"] = {
        "@type" => "AggregateRating",
        "ratingValue" => property.average_rating,
        "reviewCount" => property.reviews.count
      }
    end

    data["checkinTime"] = schema_time(property.check_in_time.presence || "3:00 PM")
    data["checkoutTime"] = schema_time(property.check_out_time.presence || "10:30 AM")
    data["priceRange"] = "\u20ac#{property.price_per_night.to_i} per night"

    data.compact
  end

  # BreadcrumbList JSON-LD from [name, url] pairs, home first. Google shows the
  # trail in place of the bare URL in results. Render it like
  # lodging_structured_data: `raw json_escape(...to_json)`.
  def breadcrumb_structured_data(crumbs)
    {
      "@context" => "https://schema.org",
      "@type" => "BreadcrumbList",
      "itemListElement" => crumbs.each_with_index.map do |(name, url), index|
        { "@type" => "ListItem", "position" => index + 1, "name" => name, "item" => url }
      end
    }
  end

  # The <title> for a listing. Ten listings are called "Double Room" or "Twin
  # Room", so the title alone gave Google ten identical page titles — the town
  # and the category are what make each one worth ranking.
  def listing_page_title(property)
    place = property.city.presence && " in #{property.city}"
    "#{property.title} — Contractor Accommodation#{place} | Crewbase"
  end

  # Schema.org wants a Time as ISO 8601 ("16:00:00"). Listings store check-in
  # and check-out as free text a host typed ("4:00 PM"), which Search Console
  # rejects as the wrong value type. Returns nil when it can't be parsed, and
  # the caller leaves the field out rather than emitting something invalid.
  def schema_time(value)
    Time.zone.parse(value.to_s)&.strftime("%H:%M:%S")
  rescue ArgumentError
    nil
  end

  # Sized variant of an uploaded image, falling back to the original for
  # anything that can't be processed — pages must never break over a thumbnail.
  def sized_image(attachment, **transform)
    attachment.variable? ? attachment.variant(**transform) : attachment
  rescue StandardError
    attachment
  end

  # Rough drive-time estimate from a straight-line distance (km): roads run ~1.25x
  # longer than a straight line, averaging ~65 km/h across Irish roads. Rounded to
  # 5 minutes because it's explicitly an approximation.
  def approx_drive_minutes(straight_km)
    return nil if straight_km.blank?

    minutes = (straight_km.to_f * 1.25 / 65.0) * 60
    [ (minutes / 5.0).round * 5, 5 ].max
  end

  def format_drive_time(minutes)
    return nil if minutes.blank?
    return "#{minutes} min" if minutes < 60

    h = minutes / 60
    m = minutes % 60
    m.zero? ? "#{h} hr" : "#{h} hr #{m} min"
  end

  # Render a user-supplied URL (a host's listing/iCal link) as a clickable link
  # only when it's a plain http(s) URL — never a "javascript:" or other scheme —
  # so viewing an application can't execute anything. Falls back to plain text.
  def safe_external_link(url, **options)
    if url.to_s.match?(%r{\Ahttps?://}i)
      link_to(url, url, **options.reverse_merge(target: "_blank", rel: "noopener"))
    else
      content_tag(:span, url.to_s)
    end
  end
end
