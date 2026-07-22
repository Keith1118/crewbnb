require "test_helper"

# Covers the front door: signing up, the role a new account is allowed to claim,
# and where each kind of user lands after signing in.
class RegistrationFlowTest < ActionDispatch::IntegrationTest
  test "a visitor can create a guest account" do
    assert_difference "User.count", 1 do
      post user_registration_path, params: { user: {
        first_name: "New", last_name: "Guest",
        email: "newguest@example.com", password: "password123!",
        password_confirmation: "password123!"
      } }
    end

    assert User.find_by(email: "newguest@example.com").guest?
  end

  test "someone can sign up as a host" do
    post user_registration_path, params: { user: {
      first_name: "New", last_name: "Host",
      email: "newhost@example.com", password: "password123!",
      password_confirmation: "password123!", role: "host"
    } }

    assert User.find_by(email: "newhost@example.com").host?
  end

  # The important guard: nobody can hand themselves admin at sign-up.
  test "a visitor cannot make themselves an admin" do
    post user_registration_path, params: { user: {
      first_name: "Sneaky", last_name: "User",
      email: "sneaky@example.com", password: "password123!",
      password_confirmation: "password123!", role: "admin"
    } }

    user = User.find_by(email: "sneaky@example.com")

    assert_not_nil user
    assert user.guest?, "self-assigned admin role should have been downgraded to guest"
  end

  test "signing up with a taken email doesn't create a second account" do
    create(:user, email: "taken@example.com")

    assert_no_difference "User.count" do
      post user_registration_path, params: { user: {
        email: "taken@example.com", password: "password123!",
        password_confirmation: "password123!"
      } }
    end
  end

  # after_sign_in_path_for sends each role to its home. Exercised through a real
  # login POST so the redirect logic actually runs.
  test "a host is sent to the host area after signing in" do
    create(:user, :host, email: "host@example.com", password: "password123!")

    post user_session_path, params: { user: { email: "host@example.com", password: "password123!" } }

    assert_redirected_to host_root_path
  end

  test "an admin is sent to the admin area after signing in" do
    create(:user, :admin, email: "admin@example.com", password: "password123!")

    post user_session_path, params: { user: { email: "admin@example.com", password: "password123!" } }

    assert_redirected_to admin_root_path
  end

  test "a guest is sent to the home page after signing in" do
    create(:user, email: "guest@example.com", password: "password123!")

    post user_session_path, params: { user: { email: "guest@example.com", password: "password123!" } }

    assert_redirected_to root_path
  end
end
