class HostApplication < ApplicationRecord
  # A host's request to list a property. Staff review it and build the polished
  # listing for them (the "premium" onboarding), so the applicant only supplies
  # proof they control the place plus the details needed to set it up.
  belongs_to :user
  belongs_to :property, optional: true
  belongs_to :reviewed_by, class_name: "User", optional: true

  enum :applicant_type, { individual: 0, company: 1 }
  enum :status, { pending: 0, approved: 1, rejected: 2 }
  enum :entity_type, {
    sole_trader: 0, limited_company: 1, plc: 2, partnership: 3, other: 4
  }, prefix: :entity

  # Proof they have the place (deeds/OTA screenshot/etc.) and, for companies,
  # registration documents. Stored on R2 via Active Storage.
  has_many_attached :proof_documents
  has_many_attached :business_documents

  # Anchored at both ends with no whitespace, so a multiline value can't slip a
  # second (e.g. "javascript:") line past the check.
  HTTP_URL = %r{\Ahttps?://\S+\z}i

  validates :property_address, :listing_url, :ical_url, presence: true
  validates :listing_url, :ical_url, format: { with: HTTP_URL, message: "must be a valid http:// or https:// URL" }, allow_blank: true
  validate  :proof_documents_present
  validate  :company_fields_present

  scope :newest_first, -> { order(created_at: :desc) }
  scope :needs_review, -> { pending.order(:created_at) }

  def company?
    applicant_type == "company"
  end

  private

  def proof_documents_present
    return if proof_documents.attached?

    errors.add(:proof_documents, "must be uploaded to show you have the place")
  end

  def company_fields_present
    return unless company?

    errors.add(:company_name, "is required for a company") if company_name.blank?
    errors.add(:entity_type, "is required for a company") if entity_type.blank?
    errors.add(:business_documents, "must be uploaded to verify the company") unless business_documents.attached?
  end
end
