class PagesController < ApplicationController
  rate_limit to: 5, within: 1.minute, only: :submit_contact,
             with: -> { redirect_to contact_path, alert: "Too many messages sent. Please wait a minute and try again." }

  def home
    # Show a small featured set on the home page — the full catalogue lives on
    # the Find stays (properties) page.
    @properties = Property.published
                          .with_attached_images
                          .order(created_at: :desc)
                          .limit(3)
  end

  def about
  end

  def contact
    @contact = ContactSubmission.new
  end

  def submit_contact
    @contact = ContactSubmission.new(contact_params)

    if @contact.save
      ContactMailer.auto_reply(@contact).deliver_later
      ContactMailer.admin_notification(@contact).deliver_later
      redirect_to contact_path, notice: "Thanks for reaching out. We'll get back to you within 24 hours."
    else
      render :contact, status: :unprocessable_entity
    end
  end

  def how_it_works
  end

  def help
  end

  def safety
  end

  def privacy
  end

  def terms
  end

  def cookies
  end

  def sitemap
    @properties = Property.published.order(updated_at: :desc)
    render formats: :xml
  end

  private

  def contact_params
    params.require(:contact_submission).permit(:name, :email, :subject, :message)
  end
end
