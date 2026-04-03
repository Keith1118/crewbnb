class ContactMailer < ApplicationMailer
  def auto_reply(contact_submission)
    @contact = contact_submission

    mail(
      to: @contact.email,
      subject: "We got your message - WorkStays"
    )
  end

  def admin_notification(contact_submission)
    @contact = contact_submission

    mail(
      to: "admin@workstays.com",
      subject: "New contact form submission: #{@contact.subject}"
    )
  end
end
