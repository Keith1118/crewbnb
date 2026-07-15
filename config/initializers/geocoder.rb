Geocoder.configure(
  lookup: :nominatim,               # free OpenStreetMap geocoder, no API key
  units: :km,                       # distances/near default to kilometres
  timeout: 5,
  # OpenStreetMap's usage policy requires a descriptive User-Agent.
  http_headers: { "User-Agent" => "Crewbnb accommodation search (https://crewbnb.ie)" },
  cache: Rails.cache,               # cache lookups to respect rate limits
  always_raise: :all
)
