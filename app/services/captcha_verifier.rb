require "net/http"
require "json"

# Cloudflare Turnstile: a captcha that stays invisible for most people, sets no
# tracking cookies, and is free. It only engages when both keys are present, so
# development and the test suite never talk to Cloudflare — the honeypot in
# SpamProtection guards the forms either way.
#
# Set TURNSTILE_SITE_KEY and TURNSTILE_SECRET_KEY (dash.cloudflare.com →
# Turnstile → add a widget for crewbase.ie) to turn it on.
class CaptchaVerifier
  ENDPOINT = "https://challenges.cloudflare.com/turnstile/v0/siteverify"

  class << self
    def site_key   = ENV["TURNSTILE_SITE_KEY"].presence
    def secret_key = ENV["TURNSTILE_SECRET_KEY"].presence
    def configured? = site_key.present? && secret_key.present?

    # False only when there's no token or Cloudflare actively rejects one. An
    # unreachable Cloudflare fails open, the way VatVerifier does with VIES — an
    # outage at their end must not swallow enquiries.
    def passed?(token, remote_ip: nil)
      return true unless configured?
      return false if token.blank?

      form = { secret: secret_key, response: token }
      form[:remoteip] = remote_ip if remote_ip.present?
      siteverify(form)
    end

    private

    def siteverify(form)
      uri = URI(ENDPOINT)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 6
      response = http.post(uri.request_uri, URI.encode_www_form(form),
                           "Content-Type" => "application/x-www-form-urlencoded")
      JSON.parse(response.body.to_s)["success"] == true
    rescue StandardError => e
      Rails.logger.warn("Turnstile verification failed: #{e.class} #{e.message}")
      true
    end
  end
end
