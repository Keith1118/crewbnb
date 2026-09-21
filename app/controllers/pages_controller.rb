class PagesController < ApplicationController
  include SpamProtection

  ENQUIRY_THANKS = "Thanks — we have your requirements and we'll come back to you within 24 hours.".freeze
  CONTACT_THANKS = "Thanks for reaching out. We'll get back to you within 24 hours.".freeze
  CAPTCHA_FAILED = "We couldn't tell you apart from a bot. Tick the box and send it again, or email us directly.".freeze

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

    # Whatever filled the honeypot is told the same thing a person is told, so
    # it has no way to work out that it was caught.
    return redirect_to root_path(anchor: "enquiry"), notice: ENQUIRY_THANKS if honeypot_filled?

    unless captcha_passed?
      @enquiry.errors.add(:base, CAPTCHA_FAILED)
      @properties = featured_properties
      return render :home, status: :unprocessable_entity
    end

    if @enquiry.valid?
      submission = @enquiry.to_contact_submission
      submission.save!
      ContactMailer.auto_reply(submission).deliver_later
      ContactMailer.admin_notification(submission).deliver_later
      redirect_to root_path(anchor: "enquiry"), notice: ENQUIRY_THANKS
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

    return redirect_to contact_path, notice: CONTACT_THANKS if honeypot_filled?

    unless captcha_passed?
      @contact.errors.add(:base, CAPTCHA_FAILED)
      return render :contact, status: :unprocessable_entity
    end

    if @contact.save
      ContactMailer.auto_reply(@contact).deliver_later
      ContactMailer.admin_notification(@contact).deliver_later
      redirect_to contact_path, notice: CONTACT_THANKS
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

  HOME_PAGE_LISTINGS = 6

  # Two rows of three: the listings staff have ticked as featured, topped up
  # with the newest published ones if fewer than six are ticked. Newest-first on
  # its own can't express the mix we want — it lands two Edenderry doubles and
  # no twin.
  def featured_properties
    chosen = Property.published.featured
                     .with_attached_images
                     .order(Arel.sql("featured_position ASC NULLS LAST"), created_at: :desc)
                     .limit(HOME_PAGE_LISTINGS)
                     .to_a
    return chosen if chosen.size >= HOME_PAGE_LISTINGS

    chosen + Property.published
                     .where.not(id: chosen.map(&:id))
                     .with_attached_images
                     .order(created_at: :desc)
                     .limit(HOME_PAGE_LISTINGS - chosen.size)
                     .to_a
  end

  def enquiry_params
    params.require(:enquiry).permit(:company, :name, :email, :phone, :location, :dates, :crew_size, :details)
  end

  def contact_params
    params.require(:contact_submission).permit(:name, :email, :subject, :message)
  end
end
