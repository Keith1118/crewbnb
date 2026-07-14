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
end
