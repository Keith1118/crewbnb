require "open-uri"

# Clear existing data
puts "Clearing existing data..."
ActiveStorage::Attachment.destroy_all
ActiveStorage::Blob.destroy_all
[ Review, Payment, Message, Conversation, Booking, Favorite, Availability, PropertyAmenity, PropertyImage, Property, Amenity, ContactSubmission, User ].each(&:destroy_all)

# ============================================================
# Amenities
# ============================================================
puts "Creating amenities..."
work_amenities = [
  { name: "Fast Wi-Fi", icon: "wifi", category: :work },
  { name: "Workspace / Desk", icon: "desk", category: :work },
  { name: "Early Breakfast Option", icon: "bakery_dining", category: :work },
  { name: "Packed Lunch on Request", icon: "lunch_dining", category: :work },
  { name: "Drying Room for Work Gear", icon: "dry_cleaning", category: :work },
  { name: "Free On-Site Parking", icon: "local_parking", category: :work }
]

comfort_amenities = [
  { name: "Heating", icon: "thermostat", category: :comfort },
  { name: "Guest Kitchen", icon: "kitchen", category: :comfort },
  { name: "Washer/Dryer", icon: "local_laundry_service", category: :comfort },
  { name: "Flat-Screen TV", icon: "tv", category: :comfort },
  { name: "Tea & Coffee Station", icon: "coffee", category: :comfort },
  { name: "Fresh Linen & Towels", icon: "bed", category: :comfort },
  { name: "Iron & Ironing Board", icon: "iron", category: :comfort },
  { name: "Weekly Housekeeping", icon: "cleaning_services", category: :comfort },
  { name: "Blackout Curtains", icon: "curtains", category: :comfort },
  { name: "Luggage Storage", icon: "luggage", category: :comfort }
]

safety_amenities = [
  { name: "Smoke Detectors", icon: "detector_smoke", category: :safety },
  { name: "Fire Extinguisher", icon: "fire_extinguisher", category: :safety },
  { name: "First Aid Kit", icon: "medical_services", category: :safety },
  { name: "Contactless Check-In", icon: "key", category: :safety },
  { name: "CCTV at Entrance", icon: "videocam", category: :safety }
]

amenities = {}
(work_amenities + comfort_amenities + safety_amenities).each do |attrs|
  amenities[attrs[:name]] = Amenity.create!(attrs)
end

standard_amenities = [
  "Fast Wi-Fi", "Free On-Site Parking", "Heating", "Guest Kitchen",
  "Tea & Coffee Station", "Fresh Linen & Towels", "Flat-Screen TV",
  "Washer/Dryer", "Iron & Ironing Board", "Weekly Housekeeping",
  "Luggage Storage", "Smoke Detectors", "Fire Extinguisher",
  "First Aid Kit", "Contactless Check-In", "CCTV at Entrance",
  "Drying Room for Work Gear", "Early Breakfast Option"
]

# ============================================================
# Users
# ============================================================
puts "Creating users..."
admin = User.create!(
  email: "admin@crewbase.ie",
  password: "password123",
  first_name: "Admin",
  last_name: "User",
  role: :admin,
  phone: "+353 87 000 0000",
  bio: "Platform administrator"
)

host = User.create!(
  email: "host1@crewbase.ie",
  password: "password123",
  first_name: "Niall",
  last_name: "Byrne",
  role: :host,
  phone: "+353 87 123 4567",
  bio: "Family-run guesthouse in the centre of Edenderry. We've hosted crews working across Offaly, Kildare, and West Dublin for years — we know what a working guest needs: a solid bed, hot shower, fast Wi-Fi, parking, and an early start without fuss."
)

guest_profiles = [
  { first: "Darren", last: "Molloy", bio: "Site foreman, mostly on jobs around the midlands." },
  { first: "Tomasz", last: "Kowalski", bio: "Electrician working with a Dublin-based contractor." },
  { first: "Sean", last: "Farrelly", bio: "Groundworks crew lead." }
]
guests = guest_profiles.each_with_index.map do |g, i|
  User.create!(
    email: "guest#{i + 1}@crewbase.ie",
    password: "password123",
    first_name: g[:first],
    last_name: g[:last],
    role: :guest,
    phone: "+353 86 55#{i}#{i} 12#{i}4",
    bio: g[:bio]
  )
end

# ============================================================
# Properties — Edenderry town-centre guesthouse, 10 rooms
# ============================================================
puts "Creating the 10 Edenderry rooms..."

EDENDERRY = {
  address: "Main Street, Town Centre",
  city: "Edenderry",
  country: "Ireland",
  latitude: 53.3439,
  longitude: -7.0498
}.freeze

NEARBY = <<~TEXT.freeze
  • Edenderry town centre on the doorstep — supermarkets (Tesco, Aldi, Lidl), pharmacies, and hardware stores within a 5-minute walk
  • Local pubs, takeaways, and cafés for evening meals — most within 200 m
  • Grand Canal Greenway — walking and cycling along the canal, 5 minutes away
  • M4 motorway 15 minutes — Dublin city and airport roughly 1 hour by car
  • Enfield train station ~15 minutes for rail to Dublin
  • Tullamore ~30 minutes, Naas ~35 minutes, Maynooth ~30 minutes — handy for jobs across the midlands and West Dublin
TEXT

HOUSE_RULES = <<~TEXT.freeze
  • No smoking anywhere inside the building (outdoor smoking area at the rear)
  • Quiet hours from 10:00 PM to 7:00 AM — most of our guests are up early for work
  • No parties or events
  • Work boots and site gear in the drying room, please — not in the bedrooms
  • Keep the shared kitchen tidy after use
  • Government-issued ID required at check-in
TEXT

rooms = [
  {
    room: 1, type: "Twin Room", price: 79, guests: 2,
    beds: "2 single beds",
    title: "Room 1 · Bright Twin Room in Edenderry Town Centre — Free Parking",
    description: <<~DESC
      A clean, comfortable twin room on the first floor of our town-centre guesthouse, ideal for two colleagues sharing on a work contract. You get two proper single beds — no pull-outs — with fresh linen, blackout curtains for early nights, and a hot power shower down the hall.

      The location does the work for you: step out the front door and you're on Edenderry's main street, with supermarkets, takeaways, and pubs all within a few minutes' walk. Free parking at the rear fits vans and pickups, and the M4 is 15 minutes away for jobs in Dublin, Kildare, or the midlands.

      Guests have full use of the shared kitchen, the laundry, and a dedicated drying room for wet gear. Wi-Fi is fast enough for video calls and streaming, and weekly stays include housekeeping. Book by the night or by the working week — either way you'll get a proper invoice for your records.
    DESC
  },
  {
    room: 2, type: "Double Room", price: 69, guests: 2,
    beds: "1 double bed",
    title: "Room 2 · Comfortable Double Room — Weekday Rates for Working Guests",
    description: <<~DESC
      A quiet double room at the back of the building, away from street noise — the pick of the house if you're a light sleeper with a 6 AM start. There's a comfortable double bed, a wardrobe, a kettle with tea and coffee, and a flat-screen TV for winding down.

      Everything a working guest needs is on site: free parking for your van, a drying room for site gear, a guest kitchen for making your own dinners, and a washer/dryer so you can travel light. The Wi-Fi handles video calls without a bother.

      Edenderry is a practical base for contracts across Offaly, Kildare, and West Dublin — the M4 is 15 minutes away and Dublin is about an hour. Weekly and monthly rates available; every booking comes with an automatic invoice.
    DESC
  },
  {
    room: 3, type: "Twin Room", price: 79, guests: 2,
    beds: "2 single beds",
    title: "Room 3 · Twin Room with Workspace — Ideal for Contractors Sharing",
    description: <<~DESC
      This first-floor twin is set up for two workmates sharing: two full-size single beds, a desk if you need to catch up on paperwork or timesheets, and plenty of storage for a week's worth of gear.

      Downstairs you'll find the shared guest kitchen — stocked with the basics — plus a laundry and a drying room built for wet hi-vis and boots. Parking at the rear is free and unmonitored-height, so vans are no problem.

      You're in the middle of Edenderry town, so food, fuel, and hardware are all within walking distance. It's an easy commute to sites around Enfield, Kinnegad, Tullamore, and the western edge of Dublin. Nightly, weekly, and longer stays welcome.
    DESC
  },
  {
    room: 4, type: "Double Room", price: 69, guests: 2,
    beds: "1 double bed",
    title: "Room 4 · Quiet Double Room — Free Van Parking & Fast Wi-Fi",
    description: <<~DESC
      A straightforward, well-kept double room for a working guest who wants a decent bed, a hot shower, and no nonsense. The double bed has fresh linen and a proper mattress, the curtains are blackout, and the radiator is yours to control.

      The guesthouse is run for working guests: contactless check-in if you're arriving late, an early breakfast option if you're gone before seven, and a packed lunch available on request. The drying room means wet gear never comes upstairs.

      Location-wise you're on Edenderry's main street — everything is walkable, and the free rear car park takes vans and trailers. Dublin is about an hour, the M4 fifteen minutes. Weekly rates and automatic invoices make it an easy sell to the office.
    DESC
  },
  {
    room: 5, type: "Twin Room", price: 79, guests: 2,
    beds: "2 single beds",
    title: "Room 5 · Twin Room Near the Grand Canal — Weekly Stays Welcome",
    description: <<~DESC
      Two single beds, a bright window looking toward the canal end of town, and a quiet corridor — Room 5 is a favourite with returning crews. Beds are made up with fresh linen and towels are included, with weekly housekeeping on longer stays.

      Shared facilities are a short walk down the hall: modern bathrooms with strong hot showers, a guest kitchen with fridge space per room, and a laundry. The drying room earns its keep in winter.

      After work, the Grand Canal Greenway is five minutes away for a walk or a run, and the town's pubs and takeaways cover the evenings. With free parking and fast Wi-Fi, it's a solid weekly base for any two-person crew working the midlands.
    DESC
  },
  {
    room: 6, type: "Triple Room", price: 105, guests: 3,
    beds: "3 single beds",
    title: "Room 6 · Large Triple Room — 3 Single Beds for Work Crews",
    description: <<~DESC
      Our biggest room on the first floor: three full single beds in a genuinely spacious room, so a three-person crew can share without living on top of each other. Each bed has its own locker and reading light; there's a wardrobe and rail for hanging gear.

      Split three ways, this is the most cost-effective way to house a crew in town — far cheaper per head than individual hotel rooms, and you're all in the same building with the same start time. The guest kitchen, laundry, and drying room are shared with the house.

      Free parking out back takes multiple vans. Edenderry town centre is out the front door, and the M4 puts Dublin, Naas, and Mullingar all within commuting range. Weekly rates available, invoice issued automatically with every booking.
    DESC
  },
  {
    room: 7, type: "Twin Room", price: 79, guests: 2,
    beds: "2 single beds",
    title: "Room 7 · Ground-Floor Twin Room — Easy Access, No Stairs",
    description: <<~DESC
      The only twin on the ground floor, Room 7 is handy if you'd rather skip the stairs after a long shift — or if you're hauling tools and bags in and out at the start and end of the week. Two single beds, fresh linen, and a window onto the quiet rear yard.

      You're steps from the guest kitchen and the drying room, and the rear car park is right outside — you can be out of bed and into the van in five minutes flat. Contactless check-in means late arrivals are never a problem.

      Like all our rooms, it comes with fast Wi-Fi, tea and coffee, weekly housekeeping on longer stays, and a proper VAT invoice for the office. Edenderry's shops and food are a two-minute walk.
    DESC
  },
  {
    room: 8, type: "Triple Room", price: 105, guests: 3,
    beds: "3 single beds",
    title: "Room 8 · Triple Room for Crews — Best Value Per Bed in Edenderry",
    description: <<~DESC
      Three single beds in a big, bright second-floor room — built for crews who want to keep the team together and the accommodation bill down. Per bed, it's the best value in the house, and you're not sharing with strangers.

      The room has blackout curtains, individual reading lights, a TV, and enough floor space that three sets of work bags don't become a hazard. Bathrooms are shared and kept spotless; showers are hot and strong when you need them at 6 AM.

      Downstairs: guest kitchen, laundry, drying room, and free parking for vans out the back. Edenderry sits 15 minutes off the M4, making it a smart base for contracts anywhere between Dublin and Athlone. Weekly rates and automatic invoicing standard.
    DESC
  },
  {
    room: 9, type: "Double Room", price: 69, guests: 2,
    beds: "1 double bed",
    title: "Room 9 · Top-Floor Double Room — Quiet & Bright with Town Views",
    description: <<~DESC
      Tucked at the top of the house, Room 9 is the quietest room we have — a comfortable double bed, sloped ceilings, and a view over the rooftops of Edenderry. If you want proper rest between shifts, this is the one.

      It comes with the same working-guest setup as the rest of the house: fast Wi-Fi, tea and coffee in the room, fresh linen and towels, and access to the guest kitchen, laundry, and drying room downstairs.

      The town centre location means you can walk to dinner, and free rear parking means the van is secure overnight. An hour from Dublin, 15 minutes from the M4, and a proper invoice with every booking — simple.
    DESC
  },
  {
    room: 10, type: "Double Room", price: 69, guests: 2,
    beds: "1 double bed",
    title: "Room 10 · Double Room with Desk — For Longer Work Placements",
    description: <<~DESC
      Room 10 is set up for the longer stay: a double bed, a proper desk and chair for paperwork or evening calls, extra wardrobe space, and a second luggage rack so a month's worth of gear has somewhere to live.

      Long-stay guests get weekly housekeeping with fresh linen and towels, full use of the kitchen and laundry, and a rate that beats any hotel in the area over a working month. The drying room and free van parking are included as standard.

      Edenderry is a genuinely practical base — big enough for supermarkets and food, small enough that nothing is more than a five-minute walk. Sites across Offaly, Kildare, Meath, and West Dublin are all within an easy commute. Monthly rates on request.
    DESC
  }
]

properties = rooms.map do |r|
  Property.create!(
    user: host,
    title: r[:title],
    description: r[:description].strip,
    property_type: r[:type],
    address: EDENDERRY[:address],
    city: EDENDERRY[:city],
    country: EDENDERRY[:country],
    latitude: EDENDERRY[:latitude],
    longitude: EDENDERRY[:longitude],
    price_per_night: r[:price],
    max_guests: r[:guests],
    bedrooms: 1,
    bathrooms: 1,
    bed_configuration: r[:beds],
    house_rules: HOUSE_RULES.strip,
    nearby_attractions: NEARBY.strip,
    check_in_time: "3:00 PM",
    check_out_time: "10:30 AM",
    wifi_speed: "150 Mbps",
    has_desk: r[:description].include?("desk"),
    has_meeting_room: false,
    has_printer: false,
    has_parking: true,
    status: :published,
    instant_book: true
  ).tap do |prop|
    standard_amenities.each do |name|
      PropertyAmenity.create!(property: prop, amenity: amenities.fetch(name))
    end
    PropertyAmenity.create!(property: prop, amenity: amenities.fetch("Workspace / Desk")) if prop.has_desk?
    PropertyAmenity.create!(property: prop, amenity: amenities.fetch("Blackout Curtains"))
  end
end

# ============================================================
# Property images (placeholders)
# ============================================================
puts "Downloading placeholder room images (this may take a minute)..."
properties.each_with_index do |property, i|
  3.times do |j|
    seed = "crewbase-edenderry-room-#{i + 1}-img-#{j}"
    begin
      image = URI.open("https://picsum.photos/seed/#{seed}/1200/900", open_timeout: 10, read_timeout: 10)
      property.images.attach(
        io: image,
        filename: "room_#{i + 1}_photo_#{j + 1}.jpg",
        content_type: "image/jpeg"
      )
      print "."
    rescue StandardError
      print "x"
    end
  end
end
puts "\n#{ActiveStorage::Attachment.where(record_type: 'Property').count} room images attached."

# ============================================================
# Bookings — past completed stays (for reviews) + upcoming
# ============================================================
puts "Creating bookings..."

def create_past_booking!(property:, guest:, check_in:, nights:)
  booking = Booking.new(
    property: property,
    user: guest,
    check_in: check_in,
    check_out: check_in + nights,
    guests_count: [ 2, property.max_guests ].min,
    status: :completed
  )
  booking.total_price = booking.calculate_total
  booking.invoice_reference = "CB-#{SecureRandom.hex(6).upcase}"
  booking.save!(validate: false)
  booking
end

past_bookings = []
[
  { property: properties[0], guest: guests[0], weeks_ago: 6, nights: 4 },
  { property: properties[1], guest: guests[1], weeks_ago: 5, nights: 5 },
  { property: properties[5], guest: guests[2], weeks_ago: 4, nights: 4 },
  { property: properties[7], guest: guests[0], weeks_ago: 3, nights: 5 },
  { property: properties[3], guest: guests[1], weeks_ago: 8, nights: 4 },
  { property: properties[9], guest: guests[2], weeks_ago: 10, nights: 19 }
].each do |b|
  monday = Date.current.beginning_of_week - (b[:weeks_ago] * 7)
  past_bookings << create_past_booking!(
    property: b[:property], guest: b[:guest], check_in: monday, nights: b[:nights]
  )
end

# A couple of upcoming confirmed stays
[
  { property: properties[2], guest: guests[0], weeks_ahead: 1, nights: 4 },
  { property: properties[6], guest: guests[1], weeks_ahead: 2, nights: 4 }
].each do |b|
  monday = Date.current.beginning_of_week + (b[:weeks_ahead] * 7)
  Booking.create!(
    property: b[:property],
    user: b[:guest],
    check_in: monday,
    check_out: monday + b[:nights],
    guests_count: 2,
    status: :confirmed
  )
end

# ============================================================
# Reviews — original, contractor-voiced
# ============================================================
puts "Creating reviews..."
review_texts = [
  { rating: 5, comment: "Stayed Monday to Friday while working on a job outside Enfield. Room was spotless, shower was roasting, and being able to park the van out the back was a big plus. Will be back next phase of the contract." },
  { rating: 5, comment: "Exactly what you want on a work week. Quiet at night, early breakfast sorted, and the drying room saved us during a wet week on site. Invoice landed in my email straight after booking — made the office happy." },
  { rating: 4, comment: "Three of us shared the triple and it worked well — proper single beds, not bunks. Kitchen was handy for making dinners instead of takeaways every night. Only note is parking fills up, get in early." },
  { rating: 5, comment: "Second stay here with the crew. Niall is sound, check-in was contactless as we landed late Sunday night, and the Wi-Fi was solid for calls home. Handy to everything in town." },
  { rating: 4, comment: "Good value for a working week — a lot cheaper than the hotels we priced, and closer to the site. Bed was comfortable, room warm, and the washing machine meant I could pack half as much." },
  { rating: 5, comment: "Was here nearly three weeks on a fit-out job. Weekly housekeeping, fresh towels, desk in the room for paperwork — genuinely set up for people working, not tourists. Recommended it to two other subbies already." }
]

past_bookings.each_with_index do |booking, i|
  text = review_texts[i % review_texts.size]
  Review.create!(
    booking: booking,
    reviewer: booking.user,
    reviewable: booking.property,
    rating: text[:rating],
    comment: text[:comment]
  )
end

# ============================================================
# Payments for completed/confirmed bookings
# ============================================================
puts "Creating payments..."
Booking.where(status: [ :confirmed, :completed ]).find_each do |booking|
  Payment.create!(
    booking: booking,
    amount: booking.total_price,
    currency: "EUR",
    stripe_payment_intent_id: "pi_seed_#{SecureRandom.hex(12)}",
    status: :succeeded
  )
end

# ============================================================
# Favorites & a sample conversation
# ============================================================
puts "Creating favorites and a conversation..."
Favorite.create!(user: guests[0], property: properties[5])
Favorite.create!(user: guests[1], property: properties[1])
Favorite.create!(user: guests[2], property: properties[7])

conv = Conversation.create!(
  participant_1: [ guests[0], host ].min_by(&:id),
  participant_2: [ guests[0], host ].max_by(&:id),
  property: properties[0]
)
[
  { user: guests[0], body: "Hi Niall, we've a crew of 4 starting a job near Rhode next month — would rooms 1 and 3 be free Monday to Friday for 3 weeks running?" },
  { user: host, body: "Hi Darren, good to hear from you. Both twins are free those weeks — book them on the site and the weekly rate will apply automatically. Drying room and parking sorted as usual." },
  { user: guests[0], body: "Perfect, booking them now. Cheers." }
].each { |m| conv.messages.create!(user: m[:user], body: m[:body], read_at: Time.current) }

puts "Seeding complete!"
puts "Admin: admin@crewbase.ie / password123"
puts "Host:  host1@crewbase.ie / password123"
puts "Guests: guest1@crewbase.ie – guest3@crewbase.ie / password123"
puts "#{Property.count} rooms, #{Booking.count} bookings, #{Review.count} reviews"
