class HostApplicationMailer < ApplicationMailer
  # Notify staff that a new host application needs review.
  def submitted(application)
    @application = application
    @applicant = application.user

    mail(
      to: contact_email,
      reply_to: @applicant.email,
      subject: "New host application — #{@application.property_address}"
    )
  end

  # Tell the host their application was approved and a listing is being set up.
  def approved(application)
    @application = application
    @applicant = application.user

    mail(
      to: @applicant.email,
      subject: "You're approved to host on Crewbase"
    )
  end

  def rejected(application)
    @application = application
    @applicant = application.user

    mail(
      to: @applicant.email,
      subject: "An update on your Crewbase host application"
    )
  end
end
