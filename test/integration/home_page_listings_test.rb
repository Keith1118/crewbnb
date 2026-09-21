require "test_helper"

class HomePageListingsTest < ActionDispatch::IntegrationTest
  setup do
    @host = create(:user, :host)
  end

  def publish(title, featured: false)
    create(:property, user: @host, title: title, status: :published, featured: featured)
  end

  test "the home page shows six listings" do
    8.times { |i| publish("Listing #{i}") }

    get root_path

    assert_response :success
    assert_select "#our-properties a.group", 6
  end

  test "featured listings are the six, whatever was published most recently" do
    featured = 6.times.map { |i| publish("Featured #{i}", featured: true) }
    3.times { |i| publish("Newer but not featured #{i}") }

    get root_path

    featured.each { |property| assert_select "#our-properties", text: /#{property.title}/ }
    assert_select "#our-properties", text: /Newer but not featured/, count: 0
  end

  test "a short featured list is topped up with the newest listings" do
    publish("The only featured one", featured: true)
    4.times { |i| publish("Filler #{i}") }

    get root_path

    # One featured + four fillers is all there is — no duplicates padding it out.
    assert_select "#our-properties a.group", 5
  end
end
