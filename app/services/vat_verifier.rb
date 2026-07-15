require "net/http"
require "json"

# Verifies an EU/Irish VAT number against the European Commission's free VIES
# service. Returns the official company name/address when available.
#
# Statuses:
#   :verified    — VIES confirms the number is registered to a business
#   :invalid     — VIES says the number is not valid
#   :bad_format  — doesn't even look like a VAT number
#   :unavailable — correct format but VIES couldn't be reached (fail-open)
class VatVerifier
  ENDPOINT = "https://ec.europa.eu/taxation_customs/vies/rest-api/ms"

  # VAT-registration country prefixes covered by VIES (EU + Northern Ireland).
  EU_COUNTRIES = %w[AT BE BG CY CZ DE DK EE EL ES FI FR HR HU IE IT LT LU LV
                    MT NL PL PT RO SE SI SK XI].freeze

  Result = Struct.new(:status, :name, :address, :vat_number, keyword_init: true) do
    def verified?   = status == :verified
    def invalid?    = status == :invalid
    def bad_format? = status == :bad_format
    # Treat an unreachable VIES as an acceptable pass so an EU outage never
    # blocks bookings — a correctly-formatted number still gets through.
    def acceptable? = status == :verified || status == :unavailable
  end

  def self.check(raw) = new(raw).check

  def initialize(raw)
    @vat = raw.to_s.upcase.gsub(/[^A-Z0-9]/, "")
  end

  def check
    return Result.new(status: :bad_format, vat_number: @vat) unless valid_format?

    country = @vat[0, 2]
    number  = @vat[2..]
    data    = lookup(country, number)
    valid   = data["isValid"]
    valid   = data["valid"] if valid.nil?

    if valid == true
      Result.new(status: :verified, vat_number: @vat,
                 name: presence(data["name"] || data["traderName"]),
                 address: normalize(data["address"] || data["traderAddress"]))
    elsif valid == false
      Result.new(status: :invalid, vat_number: @vat)
    else
      Result.new(status: :unavailable, vat_number: @vat)
    end
  rescue StandardError => e
    Rails.logger.warn("VAT VIES lookup failed for #{@vat}: #{e.class} #{e.message}")
    Result.new(status: :unavailable, vat_number: @vat)
  end

  def valid_format?
    @vat.match?(/\A[A-Z]{2}[A-Z0-9]{2,12}\z/) && EU_COUNTRIES.include?(@vat[0, 2])
  end

  private

  def lookup(country, number)
    attempts = 0
    begin
      attempts += 1
      uri = URI("#{ENDPOINT}/#{country}/vat/#{number}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 6
      response = http.get(uri.request_uri, "Accept" => "application/json")
      JSON.parse(response.body.to_s)
    rescue OpenSSL::SSL::SSLError, Net::OpenTimeout, Net::ReadTimeout, SocketError
      retry if attempts < 2
      raise
    end
  end

  def presence(value)
    value.to_s.strip.presence
  end

  def normalize(value)
    presence(value)&.gsub(/\s*\n\s*/, ", ")
  end
end
