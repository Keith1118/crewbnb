require "test_helper"

# The host "extranet": creating and editing listings, and approving or rejecting
# booking requests. This is where hosts spend their time, so it needs to hold.
class HostManagementTest < ActionDispatch::IntegrationTest
  setup { sign_in(@host = create(:user, :host)) }

  def valid_property_params
    {
      title: "New Crew House", description: "Sleeps a full crew.",
      property_type: "house", address: "2 Main St", city: "Edenderry",
      country: "Ireland", price_per_night: 90, weekday_discount: 15,
      bedrooms: 3, bathrooms: 2, max_guests: 6, status: "published",
      latitude: 53.34, longitude: -7.05
    }
  end

  # Once onboarded (an approved application), a host can self-serve new listings.
  test "an onboarded host can create a listing" do
    create(:host_application, :approved, user: @host)

    assert_difference "@host.properties.count", 1 do
      post host_properties_path, params: { property: valid_property_params }
    end
  end

  test "an invalid listing is re-rendered, not saved" do
    create(:host_application, :approved, user: @host)

    assert_no_difference "Property.count" do
      post host_properties_path, params: { property: valid_property_params.merge(title: "", price_per_night: 0) }
    end

    assert_response :unprocessable_entity
  end

  test "a new host without an approved application is sent to apply" do
    assert_no_difference "Property.count" do
      post host_properties_path, params: { property: valid_property_params }
    end

    assert_redirected_to new_host_application_path
  end

  test "a host can edit their own listing" do
    property = create(:property, user: @host, title: "Old Title")

    patch host_property_path(property), params: { property: { title: "New Title" } }

    assert_equal "New Title", property.reload.title
  end

  test "a host cannot touch another host's listing" do
    other = create(:property, user: create(:user, :host))

    # set_property scopes to current_user.properties, so this 404s rather than editing.
    patch host_property_path(other), params: { property: { title: "Hijacked" } }

    assert_response :not_found
    assert_not_equal "Hijacked", other.reload.title
  end

  test "a host can delete their listing" do
    property = create(:property, user: @host)

    assert_difference "Property.count", -1 do
      delete host_property_path(property)
    end
  end

  test "a guest is refused entry to the host area" do
    sign_in create(:user)

    get host_properties_path

    assert_redirected_to root_path
  end

  # ----- Booking approval -----

  test "approving a request confirms it and messages the guest" do
    property = create(:property, user: @host)
    booking  = create(:booking, property: property, status: :pending)

    assert_difference "Message.count", 1 do
      patch host_booking_path(booking), params: { booking: { status: "confirmed" } }
    end

    assert booking.reload.confirmed?
  end

  test "rejecting a request cancels it" do
    property = create(:property, user: @host)
    booking  = create(:booking, property: property, status: :pending)

    patch host_booking_path(booking), params: { booking: { status: "cancelled" } }

    assert booking.reload.cancelled?
  end

  test "a host cannot act on a booking for someone else's property" do
    other_booking = create(:booking, property: create(:property, user: create(:user, :host)))

    patch host_booking_path(other_booking), params: { booking: { status: "confirmed" } }

    assert_response :not_found
    assert_not other_booking.reload.confirmed?
  end
end
