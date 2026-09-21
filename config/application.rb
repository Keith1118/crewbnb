require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Crewbase
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = "Dublin"

    # The address printed on the site for people to write to.
    config.x.contact_email = ENV.fetch("CONTACT_EMAIL", "info@crewbase.ie")

    # Where mail the site sends us is delivered. Deliberately separate from the
    # address above: domain mail for info@crewbase.ie isn't reaching us, so our
    # own copies go to a mailbox we read while the public address stays on the
    # domain. Point ADMIN_EMAIL back at info@crewbase.ie once it forwards.
    config.x.admin_inbox = ENV.fetch("ADMIN_EMAIL", "tullyshome@gmail.com")
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
