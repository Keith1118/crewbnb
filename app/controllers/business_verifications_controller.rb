class BusinessVerificationsController < ApplicationController
  before_action :authenticate_user!

  def new
    redirect_to(after_path, notice: "Your business is already verified.") and return if current_user.business_verified?

    @company_name = current_user.company_name
    @vat_number = current_user.vat_number
  end

  def create
    @company_name = params[:company_name].to_s.strip
    @vat_number = params[:vat_number].to_s.strip

    if @company_name.blank? || @vat_number.blank?
      flash.now[:alert] = "Please enter both your company name and VAT number."
      return render :new, status: :unprocessable_entity
    end

    result = VatVerifier.check(@vat_number)

    if result.acceptable?
      current_user.update!(
        company_name: result.name.presence || @company_name,
        vat_number: result.vat_number,
        company_address: result.address,
        business_verified_at: Time.current
      )
      redirect_to after_path, notice: "Business verified — you're all set to book."
    elsif result.bad_format?
      flash.now[:alert] = "That doesn't look like a valid EU VAT number (e.g. IE1234567X)."
      render :new, status: :unprocessable_entity
    else
      flash.now[:alert] = "We couldn't verify that VAT number against the EU register. Please double-check it."
      render :new, status: :unprocessable_entity
    end
  end

  private

  # Where to send the guest after verifying — back to the booking they were making.
  def after_path
    session.delete(:after_verification).presence || bookings_path
  end
end
