namespace :crewbase do
  desc "DESTRUCTIVE. Wipe test bookings, payments, conversations, reviews and the test guest account. Keeps hosts, admins and all listings."
  task reset_test_data: :environment do
    # This deletes real rows from whatever database it's pointed at, so it asks
    # first rather than trusting the person running it to be in the right shell.
    unless ENV["CONFIRM"] == "yes"
      abort "Refusing to run without CONFIRM=yes. Re-run as: CONFIRM=yes bin/rails crewbase:reset_test_data"
    end

    test_guest_email = ENV.fetch("TEST_GUEST", "tullyshome+guest@gmail.com")

    counts = {
      payments: Payment.count,
      bookings: Booking.count,
      reviews: Review.count,
      messages: Message.count,
      conversations: Conversation.count
    }

    ActiveRecord::Base.transaction do
      Payment.delete_all
      Review.delete_all
      Message.delete_all
      Conversation.delete_all
      Booking.delete_all

      guest = User.find_by(email: test_guest_email)
      if guest
        guest.destroy!
        puts "Deleted test guest #{test_guest_email}"
      else
        puts "No user found for #{test_guest_email} — nothing to delete"
      end

      # Stripe ids point at objects in a sandbox that's being cleared too, so
      # leaving them would mean charging against accounts that no longer exist.
      User.where.not(stripe_account_id: nil)
          .update_all(stripe_account_id: nil, stripe_charges_enabled: false, stripe_onboarded_at: nil)
      User.where.not(stripe_customer_id: nil).update_all(stripe_customer_id: nil)
    end

    counts.each { |name, before| puts "#{name}: #{before} -> #{name.to_s.classify.constantize.count}" }
    puts "users: #{User.count} remaining, properties: #{Property.count} kept"
  end
end
