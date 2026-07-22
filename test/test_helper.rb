ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Lets tests call create(:booking) instead of FactoryBot.create(:booking).
    include FactoryBot::Syntax::Methods

    # Minitest 6 dropped Mock/#stub, so here's a small, restore-safe replacement.
    # Swaps a class method for the duration of the block, then puts the original
    # back — whether it was defined on the class or inherited. `replacement` may
    # be a callable (receives the args) or a plain value to return.
    def stub_class_method(receiver, name, replacement)
      singleton = receiver.singleton_class
      defined_here = singleton.instance_methods(false).include?(name) ||
                     singleton.private_instance_methods(false).include?(name)
      backup = :"__stub_#{name}__"
      singleton.send(:alias_method, backup, name) if defined_here
      callable = replacement.respond_to?(:call) ? replacement : ->(*) { replacement }
      singleton.send(:define_method, name) { |*a, **k, &b| callable.call(*a, **k, &b) }
      yield
    ensure
      singleton.send(:remove_method, name)
      if defined_here
        singleton.send(:alias_method, name, backup)
        singleton.send(:remove_method, backup)
      end
    end
  end
end

class ActionDispatch::IntegrationTest
  # Gives integration tests sign_in / sign_out.
  include Devise::Test::IntegrationHelpers
  # Lets tests run or assert on enqueued background jobs (mailers, etc).
  include ActiveJob::TestHelper
end
