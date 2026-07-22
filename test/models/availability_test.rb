require "test_helper"

class AvailabilityTest < ActiveSupport::TestCase
  test "an availability row needs a date" do
    assert_not build(:availability, date: nil).valid?
  end

  test "a property can only have one row per date" do
    property = create(:property)
    create(:availability, property: property, date: Date.current + 5)
    dupe = build(:availability, property: property, date: Date.current + 5)

    assert_not dupe.valid?
    assert_includes dupe.errors.attribute_names, :date
  end

  test "the same date on two properties is fine" do
    date = Date.current + 5
    create(:availability, property: create(:property), date: date)

    assert build(:availability, property: create(:property), date: date).valid?
  end
end
