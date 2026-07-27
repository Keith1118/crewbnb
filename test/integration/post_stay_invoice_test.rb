require "test_helper"
require "rake"

# The invoice is sent AFTER the stay, not when it's booked — an invoice for a
# stay that hasn't happened is really a quote, and the guest's accounts team
# wants it once the stay is a fact.
class PostStayInvoiceTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    # The task forces the inline adapter; put it back so it can't leak into
    # whatever test runs next in this process.
    @original_adapter = ActiveJob::Base.queue_adapter
    @host = create(:user, :host)
    @property = create(:property, user: @host)
    @guest = create(:user, :business_verified)

    Rake::Task.clear
    Crewbase::Application.load_tasks
  end

  teardown do
    Rake::Task.clear
    ActiveJob::Base.queue_adapter = @original_adapter
  end

  # The task delivers inline, so assert on what actually went out.
  def invoice_deliveries
    ActionMailer::Base.deliveries.count { |m| m.subject.to_s.start_with?("Invoice ") }
  end

  def run_task
    capture_io { Rake::Task["crewbase:auto_messages"].invoke }
  ensure
    Rake::Task["crewbase:auto_messages"].reenable
  end

  # check_in_not_in_past blocks creating a stay in the past, so create it in the
  # future and move it back — the same shape a real finished stay ends up in.
  def stay(check_out:, status: :confirmed)
    booking = create(:booking, property: @property, user: @guest, status: status,
                     check_in: Date.current + 30, check_out: Date.current + 32)
    booking.update_columns(check_in: check_out - 2, check_out: check_out)
    booking
  end

  test "a finished stay gets an invoice" do
    booking = stay(check_out: Date.current)

    assert_difference -> { invoice_deliveries }, 1 do
      run_task
    end

    assert_not_nil booking.reload.invoice_sent_at
  end

  test "a stay still in the future gets no invoice" do
    booking = stay(check_out: Date.current + 10)

    run_task

    assert_nil booking.reload.invoice_sent_at
  end

  test "an invoice is never sent twice" do
    booking = stay(check_out: Date.current)
    run_task
    sent_at = booking.reload.invoice_sent_at

    assert_no_difference -> { invoice_deliveries } do
      run_task
    end
    assert_equal sent_at, booking.reload.invoice_sent_at
  end

  test "a cancelled stay is never invoiced" do
    booking = stay(check_out: Date.current, status: :cancelled)

    run_task

    assert_nil booking.reload.invoice_sent_at
  end

  # A missed cron run must recover rather than skip the day permanently.
  test "a stay that ended two days ago is still caught" do
    booking = stay(check_out: Date.current - 2)

    run_task

    assert_not_nil booking.reload.invoice_sent_at
  end
end
