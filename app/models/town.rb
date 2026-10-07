# A town we have listings in, with its own landing page at
# /contractor-accommodation/:slug.
#
# These pages exist for search: "edenderry accommodation" and "contractor
# accommodation" were already earning impressions with nothing on the site
# written for them. The copy is hand-written per town so each page says
# something a listing page can't — a generated "Rooms in {town}" page is the
# thin, duplicate kind Google ignores. Everything else on the page (beds,
# prices, parking, drive times) is worked out from the live listings.
#
# Not a table: there are two towns and the copy belongs in code review.
class Town
  # Places a crew might be working, for the drive-time list. Coordinates are
  # town centres.
  Place = Data.define(:name, :latitude, :longitude)

  DUBLIN    = Place.new("Dublin city centre", 53.3498, -6.2603)
  NAAS      = Place.new("Naas", 53.2159, -6.6669)
  MAYNOOTH  = Place.new("Maynooth", 53.3813, -6.5918)
  NEWBRIDGE = Place.new("Newbridge", 53.1819, -6.7967)
  TULLAMORE = Place.new("Tullamore", 53.2739, -7.4889)
  ENFIELD   = Place.new("Enfield", 53.4153, -6.8344)
  TALLAGHT  = Place.new("Tallaght", 53.2859, -6.3733)
  CITYWEST  = Place.new("Citywest", 53.2836, -6.4250)

  attr_reader :slug, :name, :county, :latitude, :longitude, :intro, :nearby

  def initialize(slug:, name:, county:, latitude:, longitude:, intro:, nearby:)
    @slug = slug
    @name = name
    @county = county
    @latitude = latitude
    @longitude = longitude
    @intro = intro
    @nearby = nearby
  end

  ALL = [
    new(
      slug: "edenderry",
      name: "Edenderry",
      county: "Offaly",
      latitude: 53.3450, longitude: -7.0490,
      intro: [
        "Edenderry sits in the north-east corner of Offaly, right on the Kildare and Meath borders. The R402 runs to Enfield and the M4, so crews working in north Kildare, Meath or out along the M4 corridor can stay here and be on site without facing Dublin prices or Dublin traffic.",
        "The rooms are set up for people on the job: double, twin and triple rooms so a crew can share or spread out, priced by the night with a discount on weekday stays, and invoiced to the company at the end."
      ],
      nearby: [ ENFIELD, MAYNOOTH, NAAS, NEWBRIDGE, TULLAMORE, DUBLIN ]
    ),
    new(
      slug: "blessington",
      name: "Blessington",
      county: "Wicklow",
      latitude: 53.1700, longitude: -6.5330,
      intro: [
        "Blessington is on the N81 in west Wicklow, beside the Blessington Lakes. It's a straight run up to Tallaght, Citywest and the M50, and across to Naas and the M7 — close enough to commute to south and west Dublin sites, far enough out to get a whole house for a crew.",
        "The houses here, around Tulfarris Village on the lakeshore, take a full team under one roof: three bedrooms, a kitchen to cook in, and parking outside."
      ],
      nearby: [ CITYWEST, TALLAGHT, NAAS, NEWBRIDGE, DUBLIN ]
    )
  ].freeze

  def self.all
    ALL
  end

  def self.find(slug)
    ALL.find { |town| town.slug == slug.to_s } ||
      raise(ActiveRecord::RecordNotFound, "No town #{slug.inspect}")
  end

  # The town a listing belongs to, matched on its city, or nil.
  def self.for_city(city)
    ALL.find { |town| town.name.casecmp?(city.to_s.strip) }
  end

  # Towns with at least one published listing — the only ones worth linking to
  # or putting in the sitemap.
  def self.with_listings
    cities = Property.published.distinct.pluck(:city).compact.map { |c| c.strip.downcase }
    ALL.select { |town| cities.include?(town.name.downcase) }
  end

  def properties
    Property.published.where("LOWER(TRIM(city)) = ?", name.downcase)
  end

  # Straight-line km to a place — the drive-time helper turns it into minutes.
  def distance_to(place)
    Geocoder::Calculations.distance_between([ latitude, longitude ], [ place.latitude, place.longitude ], units: :km)
  end

  def to_param
    slug
  end
end
