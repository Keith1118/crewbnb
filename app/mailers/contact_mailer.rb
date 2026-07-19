class ContactMailer < ApplicationMailer
  def auto_reply(contact_submission)
    @contact = contact_submission

    mail(
      to: @contact.email,
      subject: "We got your message - Crewbase"
    )
  end

  def admin_notification(contact_submission)
    @contact = contact_submission

    mail(
      to: "info@crewbase.ie",
      subject: "New contact form submission: #{@contact.subject}"
    )
  end
end
