class ApplicationMailer < ActionMailer::Base
  default from: "bookings@crewbase.ie"
  layout "mailer"

  private

  def default_url_options
    { host: "localhost", port: 3000 }
  end
end
