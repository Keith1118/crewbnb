class ApplicationMailer < ActionMailer::Base
  # `from` stays on the crewbase.ie domain — SPF and DKIM are signed for it, and
  # mail sent as anything else lands in spam. Where our own copies are delivered
  # is a separate question: that's contact_email.
  default from: "info@crewbase.ie"
  layout "mailer"

  private

  # The inbox we read. See config.x.contact_email.
  def contact_email
    Rails.application.config.x.contact_email
  end
end
