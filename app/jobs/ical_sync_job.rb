# Refreshes every property that has an iCal feed. Scheduled hourly via
# config/recurring.yml (SolidQueue). One bad feed never aborts the batch — the
# service rescues its own failures and this guards the loop too.
class IcalSyncJob < ApplicationJob
  queue_as :default

  def perform
    Property.where.not(ical_url: [ nil, "" ]).find_each do |property|
      property.sync_ical!
    rescue => e
      Rails.logger.warn("[IcalSyncJob] property=#{property.id} failed: #{e.message}")
    end
  end
end
