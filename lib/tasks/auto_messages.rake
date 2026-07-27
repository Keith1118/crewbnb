namespace :crewbase do
  desc "Send scheduled host auto-messages: check-in reminders (day before) and review requests (after checkout). Run daily via cron."
  task auto_messages: :environment do
    # Production runs the :async job adapter, which queues into an in-process
    # thread pool. In a short-lived cron process that pool dies with the process,
    # so the notification emails would be dropped silently — and because the
    # in-app message already saved its "sent" timestamp, they'd never retry.
    # Send inline instead: this task is a one-shot, nothing is waiting on it.
    ActiveJob::Base.queue_adapter = :inline

    today = Date.current
    sent = { reminders: 0, review_requests: 0, invoices: 0 }

    # Check-in reminders — confirmed stays starting tomorrow
    Booking.where(status: :confirmed, check_in: today + 1, reminder_sent_at: nil).find_each do |booking|
      AutoMessenger.checkin_reminder(booking)
      sent[:reminders] += 1
    end

    # Review requests — stays that have just ended (checkout in the last 3 days)
    Booking.where(status: [ :confirmed, :completed ], review_request_sent_at: nil)
           .where(check_out: (today - 3)..today).find_each do |booking|
      AutoMessenger.review_request(booking)
      sent[:review_requests] += 1
    end

    # Invoices — sent once the stay is a fact, not when it was booked. Same
    # 3-day catch-up window as review requests, so a missed cron run recovers.
    Booking.where(status: [ :confirmed, :completed ], invoice_sent_at: nil)
           .where(check_out: (today - 3)..today).find_each do |booking|
      BookingMailer.invoice(booking).deliver_later
      booking.update_column(:invoice_sent_at, Time.current)
      sent[:invoices] += 1
    end

    puts "crewbase:auto_messages — #{sent[:reminders]} reminder(s), " \
         "#{sent[:review_requests]} review request(s), #{sent[:invoices]} invoice(s) sent."
  end
end
