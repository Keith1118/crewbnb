require "test_helper"

class ReviewTest < ActiveSupport::TestCase
  test "a review needs a rating and a comment" do
    review = Review.new

    assert_not review.valid?
    assert_includes review.errors.attribute_names, :rating
    assert_includes review.errors.attribute_names, :comment
  end

  test "the rating must be between 1 and 5" do
    assert_not build(:review, rating: 0).valid?
    assert_not build(:review, rating: 6).valid?
    assert build(:review, rating: 3).valid?
  end

  test "a valid review persists" do
    assert create(:review).persisted?
  end
end
