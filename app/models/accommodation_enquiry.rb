# Pre-launch lead capture. Bookings are closed (see BOOKINGS_OPEN), so the home
# page asks companies to tell us what their crew needs and we reply by email.
#
# There's no table behind this: an enquiry is composed into a ContactSubmission
# so it lands in the admin inbox and triggers the same auto-reply and admin
# notification every other message does. If enquiries become the main way work
# arrives, give them their own model and pipeline.
class AccommodationEnquiry
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :company, :string
  attribute :name, :string
  attribute :email, :string
  attribute :phone, :string
  attribute :location, :string
  attribute :dates, :string
  attribute :crew_size, :integer
  attribute :details, :string

  validates :company, presence: true
  validates :name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :location, presence: true
  validates :crew_size, numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 500 },
                        allow_nil: true

  def to_contact_submission
    ContactSubmission.new(
      name: name,
      email: email,
      subject: "Accommodation enquiry — #{company}",
      message: message_body
    )
  end

  private

  # Everything the enquiry form collects, flattened into the message body the
  # admin inbox and the notification email already render.
  def message_body
    lines = [
      [ "Company",  company ],
      [ "Contact",  name ],
      [ "Email",    email ],
      [ "Phone",    phone ],
      [ "Location", location ],
      [ "Dates",    dates ],
      [ "Crew size", crew_size&.to_s ]
    ].filter_map { |label, value| "#{label}: #{value}" if value.present? }

    lines << "\n#{details}" if details.present?
    lines.join("\n")
  end
end
