module ApplicationHelper
  include Pagy::Frontend

  def meta_description(text = nil)
    if text
      content_for(:meta_description, text)
    else
      content_for?(:meta_description) ? content_for(:meta_description) : "WorkStays — Book crew accommodation near your job site. Weekday pricing, automatic invoices, stays built for workers."
    end
  end

  def meta_image
    content_for?(:meta_image) ? content_for(:meta_image) : "#{request.base_url}/icon.png"
  end
end
