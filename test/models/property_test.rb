require "test_helper"

class PropertyTest < ActiveSupport::TestCase
  test "a listing needs a title, description and a positive nightly price" do
    property = Property.new(user: create(:user, :host))

    assert_not property.valid?
    assert_includes property.errors.attribute_names, :title
    assert_includes property.errors.attribute_names, :description
    assert_includes property.errors.attribute_names, :price_per_night
  end

  test "the nightly price must be greater than zero" do
    assert_not build(:property, price_per_night: 0).valid?
  end

  test "the weekday discount is limited to the offered tiers" do
    assert build(:property, weekday_discount: 20).valid?
    assert_not build(:property, weekday_discount: 17).valid?
  end

  test "published scope only returns published listings" do
    live = create(:property, status: :published)
    create(:property, :draft)

    assert_equal [ live ], Property.published.to_a
  end

  test "weekly_price is five nights" do
    assert_equal 400, create(:property, price_per_night: 80).weekly_price
  end

  test "typical_weekend_rate grosses the discount back up" do
    # A €80 rate set as 20% below the weekend rate implies a €100 weekend rate.
    assert_equal 100, create(:property, price_per_night: 80, weekday_discount: 20).typical_weekend_rate
  end

  test "average_rating summarises the property's reviews" do
    property = create(:property)
    b1 = create(:booking, :confirmed, property: property, status: :completed)
    b2 = create(:booking, property: property, status: :completed,
                          check_in: Date.current + 30, check_out: Date.current + 33)
    create(:review, booking: b1, reviewable: property, rating: 4)
    create(:review, booking: b2, reviewable: property, rating: 5)

    assert_equal 4.5, property.reload.average_rating
  end

  test "available_between? is false when a confirmed booking overlaps" do
    property = create(:property)
    create(:booking, :confirmed, property: property,
                                 check_in: Date.current + 7, check_out: Date.current + 10)

    assert_not property.available_between?(Date.current + 8, Date.current + 9)
    assert property.available_between?(Date.current + 20, Date.current + 22)
  end

  test "available_between? is false when the host has blocked a night" do
    property = create(:property)
    create(:availability, property: property, date: Date.current + 8, available: false)

    assert_not property.available_between?(Date.current + 7, Date.current + 10)
  end

  test "full_address joins the parts that are present" do
    property = build(:property, address: "1 Main St", city: "Edenderry", country: "Ireland")

    assert_equal "1 Main St, Edenderry, Ireland", property.full_address
  end
end
