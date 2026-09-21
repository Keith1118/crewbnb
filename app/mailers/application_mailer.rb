class ApplicationMailer < ActionMailer::Base
  # `from` stays on the crewbase.ie domain — SPF and DKIM are signed for it, and
  # mail sent as anything else lands in spam. Where our own copies are delivered
  # is a separate question: that's admin_inbox.
  default from: "info@crewbase.ie"
  layout "mailer"

  private

  # The inbox we read, which is not the address shown on the site. See
  # config.x.admin_inbox.
  def admin_inbox
    Rails.application.config.x.admin_inbox
  end
end
