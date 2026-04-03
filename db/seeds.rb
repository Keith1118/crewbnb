require "open-uri"

# Clear existing data
puts "Clearing existing data..."
ActiveStorage::Attachment.destroy_all
ActiveStorage::Blob.destroy_all
[Review, Payment, Message, Conversation, Booking, Favorite, Availability, PropertyAmenity, PropertyImage, Property, Amenity, User].each(&:destroy_all)

# Create amenities
puts "Creating amenities..."
work_amenities = [
  { name: "High-Speed WiFi", icon: "wifi", category: :work },
  { name: "Dedicated Desk", icon: "desk", category: :work },
  { name: "Meeting Room", icon: "meeting_room", category: :work },
  { name: "Printer/Scanner", icon: "print", category: :work },
  { name: "Monitor", icon: "monitor", category: :work },
  { name: "Whiteboard", icon: "dashboard", category: :work }
]

comfort_amenities = [
  { name: "Air Conditioning", icon: "ac_unit", category: :comfort },
  { name: "Heating", icon: "thermostat", category: :comfort },
  { name: "Kitchen", icon: "kitchen", category: :comfort },
  { name: "Washer/Dryer", icon: "local_laundry_service", category: :comfort },
  { name: "TV", icon: "tv", category: :comfort },
  { name: "Coffee Machine", icon: "coffee", category: :comfort },
  { name: "Gym Access", icon: "fitness_center", category: :comfort },
  { name: "Pool", icon: "pool", category: :comfort }
]

safety_amenities = [
  { name: "Smoke Detector", icon: "detector_smoke", category: :safety },
  { name: "Fire Extinguisher", icon: "fire_extinguisher", category: :safety },
  { name: "First Aid Kit", icon: "medical_services", category: :safety },
  { name: "Security Camera", icon: "videocam", category: :safety },
  { name: "Safe", icon: "lock", category: :safety }
]

all_amenities = (work_amenities + comfort_amenities + safety_amenities).map do |attrs|
  Amenity.create!(attrs)
end

# Create admin
puts "Creating admin user..."
admin = User.create!(
  email: "admin@workstays.com",
  password: "password123",
  first_name: "Admin",
  last_name: "User",
  role: :admin,
  phone: "+1-555-000-0000",
  bio: "Platform administrator"
)

# Create hosts
puts "Creating hosts..."
hosts = 5.times.map do |i|
  User.create!(
    email: "host#{i+1}@workstays.com",
    password: "password123",
    first_name: Faker::Name.first_name,
    last_name: Faker::Name.last_name,
    role: :host,
    phone: Faker::PhoneNumber.phone_number,
    bio: Faker::Lorem.paragraph(sentence_count: 3)
  )
end

# Create guests
puts "Creating guests..."
guests = 8.times.map do |i|
  User.create!(
    email: "guest#{i+1}@workstays.com",
    password: "password123",
    first_name: Faker::Name.first_name,
    last_name: Faker::Name.last_name,
    role: :guest,
    phone: Faker::PhoneNumber.phone_number,
    bio: Faker::Lorem.paragraph(sentence_count: 2)
  )
end

# Create properties
puts "Creating properties..."
cities = [
  { city: "Houston", country: "USA", lat: 29.7604, lng: -95.3698 },
  { city: "Calgary", country: "Canada", lat: 51.0447, lng: -114.0719 },
  { city: "Perth", country: "Australia", lat: -31.9505, lng: 115.8605 },
  { city: "Aberdeen", country: "UK", lat: 57.1497, lng: -2.0943 },
  { city: "Dubai", country: "UAE", lat: 25.2048, lng: 55.2708 },
  { city: "Denver", country: "USA", lat: 39.7392, lng: -104.9903 },
  { city: "Edmonton", country: "Canada", lat: 53.5461, lng: -113.4938 },
  { city: "Midland", country: "USA", lat: 31.9973, lng: -102.0779 }
]

property_types = ["Apartment", "House", "Studio", "Condo", "Townhouse"]
wifi_speeds = ["100 Mbps", "250 Mbps", "500 Mbps", "1 Gbps"]

properties = 20.times.map do |i|
  loc = cities.sample
  host = hosts.sample
  Property.create!(
    user: host,
    title: "#{Faker::Company.catch_phrase} #{property_types.sample}",
    description: Faker::Lorem.paragraphs(number: 3).join("\n\n"),
    property_type: property_types.sample,
    address: Faker::Address.street_address,
    city: loc[:city],
    country: loc[:country],
    latitude: loc[:lat] + rand(-0.05..0.05),
    longitude: loc[:lng] + rand(-0.05..0.05),
    price_per_night: rand(75..350),
    max_guests: rand(1..8),
    bedrooms: rand(1..4),
    bathrooms: rand(1..3),
    wifi_speed: wifi_speeds.sample,
    has_desk: [true, true, true, false].sample,
    has_meeting_room: [true, false, false].sample,
    has_printer: [true, false].sample,
    has_parking: [true, true, false].sample,
    status: :published,
    instant_book: [true, false].sample
  ).tap do |prop|
    # Add random amenities
    all_amenities.sample(rand(5..12)).each do |amenity|
      PropertyAmenity.create!(property: prop, amenity: amenity)
    end
  end
end

# Attach property images
puts "Downloading property images (this may take a minute)..."
properties.each_with_index do |property, i|
  3.times do |j|
    seed = "workstays-prop-#{i}-img-#{j}"
    begin
      image = URI.open("https://picsum.photos/seed/#{seed}/800/600", open_timeout: 10, read_timeout: 10)
      property.images.attach(
        io: image,
        filename: "property_#{property.id}_#{j}.jpg",
        content_type: "image/jpeg"
      )
      print "."
    rescue StandardError => e
      print "x"
    end
  end
end
puts "\n#{ActiveStorage::Attachment.where(record_type: 'Property').count} property images attached."

# Create bookings
puts "Creating bookings..."
bookings = 15.times.map do |i|
  property = properties.sample
  guest = guests.sample
  check_in = Faker::Date.between(from: 1.month.ago, to: 2.months.from_now)
  check_out = check_in + rand(3..14).days
  status = [:pending, :confirmed, :completed, :cancelled].sample

  Booking.create!(
    property: property,
    user: guest,
    check_in: check_in,
    check_out: check_out,
    guests_count: rand(1..property.max_guests),
    status: status,
    special_requests: [nil, Faker::Lorem.sentence].sample
  )
end

# Create reviews for completed bookings
puts "Creating reviews..."
bookings.select(&:completed?).each do |booking|
  Review.create!(
    booking: booking,
    reviewer: booking.user,
    reviewable: booking.property,
    rating: rand(3..5),
    comment: Faker::Lorem.paragraph(sentence_count: 2)
  )
end

# Create payments for confirmed/completed bookings
puts "Creating payments..."
bookings.select { |b| b.confirmed? || b.completed? }.each do |booking|
  Payment.create!(
    booking: booking,
    amount: booking.total_price,
    currency: "USD",
    stripe_payment_intent_id: "pi_#{SecureRandom.hex(12)}",
    status: :succeeded
  )
end

# Create some favorites
puts "Creating favorites..."
guests.each do |guest|
  properties.sample(rand(2..5)).each do |property|
    Favorite.find_or_create_by!(user: guest, property: property)
  end
end

# Create conversations and messages
puts "Creating conversations..."
5.times do
  guest = guests.sample
  property = properties.sample
  conv = Conversation.create!(
    participant_1: guest,
    participant_2: property.user,
    property: property
  )

  rand(3..8).times do
    sender = [guest, property.user].sample
    Message.create!(
      conversation: conv,
      user: sender,
      body: Faker::Lorem.sentence(word_count: rand(5..20)),
      read_at: [nil, Time.current].sample
    )
  end
end

puts "Seeding complete!"
puts "Admin: admin@workstays.com / password123"
puts "Hosts: host1@workstays.com through host5@workstays.com / password123"
puts "Guests: guest1@workstays.com through guest8@workstays.com / password123"
puts "#{Property.count} properties, #{Booking.count} bookings, #{Review.count} reviews"
