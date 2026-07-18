namespace :crewbase do
  desc "Send scheduled host auto-messages: check-in reminders (day before) and review requests (after checkout). Run daily via cron."
  task auto_messages: :environment do
    today = Date.current
    sent = { reminders: 0, review_requests: 0 }

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

    puts "crewbase:auto_messages — #{sent[:reminders]} reminder(s), #{sent[:review_requests]} review request(s) sent."
  end
end
