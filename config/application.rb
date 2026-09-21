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

    # The inbox that everything the site sends us lands in, and the address
    # shown to visitors. Domain mail for info@crewbase.ie isn't reaching us, so
    # this points at a mailbox we actually read; set CONTACT_EMAIL to move it.
    config.x.contact_email = ENV.fetch("CONTACT_EMAIL", "tullyshome@gmail.com")
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
