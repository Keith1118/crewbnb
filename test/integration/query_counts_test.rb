require "test_helper"

# Guards the list pages against N+1s: the query count must not grow with the
# number of rows on the page.
class QueryCountsTest < ActionDispatch::IntegrationTest
  def count_queries
    names = []
    counter = ->(_name, _start, _finish, _id, payload) do
      names << payload[:name] unless payload[:name].to_s.in?(%w[SCHEMA TRANSACTION])
    end
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { yield }
    names
  end

  # An N+1 shows up as the count growing with the rows. A couple of extra
  # queries is normal (pagination counts, a lookup that only fires when rows
  # exist), so allow a small constant but not growth proportional to the data.
  def assert_no_query_growth(before, after, message)
    assert after.size <= before.size + 2,
           "#{message}\n  #{before.size} queries -> #{after.size}\n  extra: " \
           "#{(after.tally.to_a - before.tally.to_a).inspect}"
  end

  test "the property listing does not issue more queries as listings are added" do
    host = create(:user, :host)
    create(:property, user: host)
    get properties_path
    assert_response :success
    baseline = count_queries { get properties_path }

    9.times { create(:property, user: host) }
    get properties_path
    assert_response :success
    with_ten = count_queries { get properties_path }

    assert_no_query_growth baseline, with_ten,
      "listing 10 properties should not cost more queries than listing 1"
  end

  test "a guest's bookings page does not query per booking" do
    guest = create(:user, :business_verified)
    host = create(:user, :host)
    property = create(:property, user: host)
    create(:booking, property: property, user: guest,
                     check_in: Date.current + 5, check_out: Date.current + 7)

    sign_in guest
    get bookings_path
    assert_response :success
    baseline = count_queries { get bookings_path }

    5.times do |i|
      create(:booking, property: create(:property, user: host), user: guest,
                       check_in: Date.current + 20 + (i * 5),
                       check_out: Date.current + 22 + (i * 5))
    end
    get bookings_path
    assert_response :success
    with_six = count_queries { get bookings_path }

    assert_no_query_growth baseline, with_six,
      "six bookings should not cost more queries than one"
  end

  test "the conversations inbox does not query per conversation" do
    guest = create(:user, :business_verified)
    host = create(:user, :host)

    2.times do
      property = create(:property, user: host)
      convo = Conversation.create!(participant_1: [ guest, host ].min_by(&:id),
                                   participant_2: [ guest, host ].max_by(&:id),
                                   property: property)
      convo.messages.create!(user: host, body: "hello")
    end

    sign_in guest
    get conversations_path
    assert_response :success
    baseline = count_queries { get conversations_path }

    4.times do
      property = create(:property, user: host)
      convo = Conversation.create!(participant_1: [ guest, host ].min_by(&:id),
                                   participant_2: [ guest, host ].max_by(&:id),
                                   property: property)
      convo.messages.create!(user: host, body: "hello again")
    end
    get conversations_path
    assert_response :success
    with_six = count_queries { get conversations_path }

    assert_no_query_growth baseline, with_six,
      "six conversations should not cost more queries than two"
  end
end
