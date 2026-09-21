class PagesController < ApplicationController
  rate_limit to: 5, within: 1.minute, only: :submit_contact,
             with: -> { redirect_to contact_path, alert: "Too many messages sent. Please wait a minute and try again." }
  rate_limit to: 5, within: 1.minute, only: :submit_enquiry,
             with: -> { redirect_to root_path(anchor: "enquiry"), alert: "Too many enquiries sent. Please wait a minute and try again." }

  def home
    @enquiry = AccommodationEnquiry.new
    @properties = featured_properties
  end

  # The home page is an enquiry landing page while bookings are closed: the
  # enquiry is stored and mailed as a contact submission (see
  # AccommodationEnquiry), so it reaches us exactly like any other message.
  def submit_enquiry
    @enquiry = AccommodationEnquiry.new(enquiry_params)

    if @enquiry.valid?
      submission = @enquiry.to_contact_submission
      submission.save!
      ContactMailer.auto_reply(submission).deliver_later
      ContactMailer.admin_notification(submission).deliver_later
      redirect_to root_path(anchor: "enquiry"),
                  notice: "Thanks — we have your requirements and we'll come back to you within 24 hours."
    else
      @properties = featured_properties
      render :home, status: :unprocessable_entity
    end
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

  # A small featured set for the home page — the full catalogue lives on the
  # Find stays (properties) page.
  def featured_properties
    Property.published
            .with_attached_images
            .order(created_at: :desc)
            .limit(3)
  end

  def enquiry_params
    params.require(:enquiry).permit(:company, :name, :email, :phone, :location, :dates, :crew_size, :details)
  end

  def contact_params
    params.require(:contact_submission).permit(:name, :email, :subject, :message)
  end
end
