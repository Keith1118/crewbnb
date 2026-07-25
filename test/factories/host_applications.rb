FactoryBot.define do
  factory :host_application do
    association :user, factory: [ :user, :host ]
    applicant_type { :individual }
    property_address { "12 Crew Terrace, Edenderry, Ireland" }
    listing_url { "https://www.airbnb.com/rooms/123456" }
    ical_url { "https://www.airbnb.com/calendar/ical/123456.ics" }

    # A valid application needs proof documents attached.
    after(:build) do |application|
      application.proof_documents.attach(
        io: StringIO.new("proof"), filename: "proof.pdf", content_type: "application/pdf"
      )
    end

    trait :company do
      applicant_type { :company }
      company_name { "Musgrave Group" }
      entity_type { :limited_company }

      after(:build) do |application|
        application.business_documents.attach(
          io: StringIO.new("cro"), filename: "registration.pdf", content_type: "application/pdf"
        )
      end
    end

    trait :approved do
      status { :approved }
    end

    trait :rejected do
      status { :rejected }
    end
  end
end
