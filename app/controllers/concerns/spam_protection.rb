# Two layers in front of the forms anyone on the internet can post to:
#
#   * a honeypot field nobody can see, tab into, or autofill. Bots fill every
#     field they find. A caught submission is answered exactly as a real one is,
#     so whatever filled it learns nothing.
#   * Cloudflare Turnstile, once its keys are set (see CaptchaVerifier). Until
#     then the honeypot carries the forms on its own.
module SpamProtection
  extend ActiveSupport::Concern

  # Named like something a bot would want to fill and a person would never see.
  HONEYPOT_FIELD = :company_website

  private

  def honeypot_filled?
    params[HONEYPOT_FIELD].present?
  end

  def captcha_passed?
    CaptchaVerifier.passed?(params["cf-turnstile-response"], remote_ip: request.remote_ip)
  end
end
