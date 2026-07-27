module Admin
  class PaymentsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin

    def refund
      payment = Payment.find(params[:id])
      result = PaymentRefunder.call(payment, amount: params[:amount].presence)

      if result.ok?
        redirect_to admin_booking_path(payment.booking),
                    notice: "Refunded €#{number_with_precision(result.amount, precision: 2)} to the guest. The host's payout and our commission were reversed to match."
      else
        redirect_to admin_booking_path(payment.booking), alert: "Refund failed: #{result.error}"
      end
    end

    private

    def require_admin
      unless current_user.admin?
        redirect_to root_path, alert: "You must be an admin to access this area."
      end
    end

    def number_with_precision(...) = ActiveSupport::NumberHelper.number_to_rounded(...)
  end
end
