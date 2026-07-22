require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "a new user needs a valid email and a password" do
    user = User.new(first_name: "Test")

    assert_not user.valid?
    assert_includes user.errors.attribute_names, :email
    assert_includes user.errors.attribute_names, :password
  end

  test "email must be unique" do
    create(:user, email: "taken@example.com")
    dupe = build(:user, email: "taken@example.com")

    assert_not dupe.valid?
    assert_includes dupe.errors.attribute_names, :email
  end

  test "new sign-ups default to the guest role" do
    assert build(:user).guest?
  end

  test "a fresh user is not business verified" do
    assert_not build(:user).business_verified?
  end

  test "business_verified? follows the verification timestamp" do
    assert create(:user, :business_verified).business_verified?
  end

  test "roles are distinct" do
    assert create(:user, :host).host?
    assert create(:user, :admin).admin?
    assert_not create(:user, :host).guest?
  end

  test "a password shorter than Devise's minimum is rejected" do
    user = build(:user, password: "short")

    assert_not user.valid?
    assert_includes user.errors.attribute_names, :password
  end
end
