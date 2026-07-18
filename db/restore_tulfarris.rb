# Non-destructive restore of the three real Tulfarris Village (Blessington,
# Co. Wicklow) homes, recovered from the owner's live Airbnb listings.
# Safe to re-run: it finds-or-creates by title and only attaches images when
# a property has none. It never deletes existing data.
require "open-uri"

SCRATCH = "/private/tmp/claude-501/-Users-keithmckeown-crewbase/6f81cc88-6109-4b77-820d-966e3fcb570d/scratchpad".freeze

host = User.find_by(email: "host1@crewbase.ie") || User.where(role: :host).first
raise "No host user found" unless host

# Amenities — reuse existing where present, create if missing.
def amenity(name, icon, category)
  Amenity.find_or_create_by!(name: name) { |a| a.icon = icon; a.category = category }
end

common_amenities = [
  amenity("Fast Wi-Fi", "wifi", :work),
  amenity("Free On-Site Parking", "local_parking", :work),
  amenity("Fully Equipped Kitchen", "kitchen", :comfort),
  amenity("Heating", "thermostat", :comfort),
  amenity("Smart TV", "tv", :comfort),
  amenity("Washer/Dryer", "local_laundry_service", :comfort),
  amenity("Fresh Linen & Towels", "bed", :comfort),
  amenity("Private Garden", "yard", :comfort),
  amenity("En-suite Bathrooms", "bathroom", :comfort),
  amenity("Golf Course Setting", "golf_course", :comfort),
  amenity("Smoke Detectors", "detector_smoke", :safety),
  amenity("Fire Extinguisher", "fire_extinguisher", :safety),
  amenity("First Aid Kit", "medical_services", :safety)
]

NEARBY = <<~TEXT.strip.freeze
  • Tulfarris Hotel & Golf Course — on site (award-winning 18-hole championship course overlooking the Blessington Lakes)
  • Blessington Greenway and the lakeshore — walking and cycling on the doorstep
  • Poulaphouca House & Falls — 3 km
  • Russborough House — 7 km
  • Punchestown Racecourse — 15 km
  • Glendalough — 25 km
  • The Curragh & K Club — ~25–30 km
  • Lough Tay (Guinness Lake) — 35 km
  • Dublin city and airport — roughly 1 hour by car
TEXT

HOUSE_RULES = <<~TEXT.strip.freeze
  • Check-in from 4:00 PM, check-out by 11:00 AM
  • No smoking indoors
  • No parties or events
  • Quiet hours 10:00 PM – 8:00 AM out of respect for neighbours in the village
  • Pets by prior arrangement only
  • Please leave the home as you found it — it's someone's pride and joy
TEXT

homes = [
  {
    airbnb_id: "48807795",
    title: "Three-Bedroom Home in Tulfarris Village, Wicklow",
    price: 225,
    lat: 53.12498, lng: -6.56076,
    extras: "a private garden and a living room with smart TV",
    description: <<~DESC
      A spacious 3-bedroom home set on the award-winning Tulfarris Golf Course, overlooking the Blessington Lakes in the heart of County Wicklow. The house has three en-suite bathrooms, a bright living room with a smart TV, a private garden, and a fully equipped kitchen with a dining area — comfortable for a family, a group of friends, or a work crew who'd rather share a proper house than book separate hotel rooms.

      You're in one of Wicklow's most scenic settings: golf and the lakes on your doorstep, with Blessington, Poulaphouca, and Russborough House all a short drive away, and Dublin reachable in about an hour. Free parking is right at the door.

      Sleeps up to 5 guests across 3 bedrooms. Weekly and longer stays welcome, with a proper invoice issued for every booking.
    DESC
  },
  {
    airbnb_id: "903066345341864590",
    title: "Tully's Home, Tulfarris Village, Wicklow",
    price: 235,
    lat: 53.12386, lng: -6.5536,
    extras: "a conservatory and a living room with smart TV",
    description: <<~DESC
      Tully's Home is a welcoming 3-bedroom house on the award-winning Tulfarris Golf Course, overlooking the Blessington Lakes. It offers three en-suite bathrooms, a living room with a smart TV, a bright conservatory to sit and take in the surroundings, and a fully equipped kitchen with a dining area.

      The location is hard to beat — championship golf and the lakeshore right outside, Ireland's Ancient East and the Blessington Greenway close by, and easy access to Poulaphouca Falls, Russborough House, Glendalough, and Dublin within about an hour.

      Sleeps up to 5 guests across 3 bedrooms. Ideal for families, golfing trips, or teams working in the area who want the comfort of a full house. Every booking includes an automatic invoice.
    DESC
  },
  {
    airbnb_id: "1283261381255746051",
    title: "Retreat in Tulfarris, Wicklow",
    price: 220,
    lat: 53.1253, lng: -6.5603,
    extras: "a private garden and a living room with TV",
    description: <<~DESC
      A relaxing 3-bedroom retreat on the award-winning Tulfarris Golf Course, overlooking the Blessington Lakes. The home has three en-suite bathrooms, a comfortable living room with a TV, a private garden, and a fully equipped kitchen with a dining area — a calm, well-appointed base for exploring Wicklow.

      Golf and the lakes are on your doorstep, with the Blessington Greenway, Poulaphouca Falls, Russborough House, and Glendalough all within easy reach, and Dublin about an hour away by car. Free parking is included.

      Sleeps up to 5 guests across 3 bedrooms. Great for families, friends, or working groups. A proper invoice is issued with every booking.
    DESC
  }
]

homes.each do |h|
  prop = Property.find_or_initialize_by(title: h[:title])
  prop.assign_attributes(
    user: host,
    description: h[:description].strip,
    property_type: "House",
    address: "Tulfarris Village, Blessington",
    city: "Blessington",
    country: "Ireland",
    latitude: h[:lat],
    longitude: h[:lng],
    price_per_night: h[:price],
    max_guests: 5,
    bedrooms: 3,
    bathrooms: 3,
    bed_configuration: "3 bedrooms, sleeps 5 — all en-suite",
    house_rules: HOUSE_RULES,
    nearby_attractions: NEARBY,
    check_in_time: "4:00 PM",
    check_out_time: "11:00 AM",
    wifi_speed: "100 Mbps",
    has_desk: false,
    has_meeting_room: false,
    has_printer: false,
    has_parking: true,
    status: :published,
    instant_book: true
  )
  prop.save!

  # Amenities (idempotent)
  common_amenities.each do |am|
    PropertyAmenity.find_or_create_by!(property: prop, amenity: am)
  end

  # Images — only if none attached yet
  if prop.images.attached?
    puts "#{h[:title]} — already has #{prop.images.count} images, skipping download"
  else
    urls = File.read("#{SCRATCH}/imgs_#{h[:airbnb_id]}.txt").split("\n").map(&:strip).reject(&:empty?)
    attached = 0
    urls.each_with_index do |url, idx|
      begin
        io = URI.open(url, "User-Agent" => "Mozilla/5.0", open_timeout: 15, read_timeout: 20)
        prop.images.attach(io: io, filename: "tulfarris_#{h[:airbnb_id]}_#{idx + 1}.jpg", content_type: "image/jpeg")
        attached += 1
        print "."
      rescue StandardError => e
        print "x"
      end
    end
    puts "\n#{h[:title]} — #{attached} images attached"
  end
end

puts "Done. Tulfarris homes now in the catalogue: #{Property.where('title ILIKE ?', '%tulfarris%').or(Property.where('city = ?', 'Blessington')).count}"
puts "Total published properties: #{Property.published.count}"
