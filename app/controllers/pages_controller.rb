class PagesController < ApplicationController
  def home
    @properties = Property.published
                          .order(created_at: :desc)
                          .limit(9)
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

  private

  def contact_params
    params.require(:contact_submission).permit(:name, :email, :subject, :message)
  end
end
