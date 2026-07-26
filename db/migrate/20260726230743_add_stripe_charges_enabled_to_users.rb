class AddStripeChargesEnabledToUsers < ActiveRecord::Migration[8.1]
  def change
    # Whether the host has finished Stripe Express onboarding and can actually
    # receive payouts. Kept in sync via the account.updated webhook.
    add_column :users, :stripe_charges_enabled, :boolean, default: false, null: false
    add_column :users, :stripe_onboarded_at, :datetime
  end
end
