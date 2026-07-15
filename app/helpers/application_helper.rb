module ApplicationHelper
  include Pagy::Frontend

  def meta_description(text = nil)
    if text
      content_for(:meta_description, text)
    else
      content_for?(:meta_description) ? content_for(:meta_description) : "Crewbnb — book accommodation for working crews of every kind: construction, film, engineering, business teams and more. Weekday pricing, automatic invoices, stays built for people who travel for work."
    end
  end

  def meta_image
    content_for?(:meta_image) ? content_for(:meta_image) : "#{request.base_url}/icon.png"
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
end
