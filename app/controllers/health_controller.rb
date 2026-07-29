# The endpoint Render polls to decide whether this instance is healthy.
#
# Rails' built-in rails/health#show only proves the process is running. When a
# database credential rotation left the app unable to authenticate, every page
# on the site returned 500 while /up cheerfully returned 200 — so Render saw a
# healthy service, never restarted it, never rolled back and never alerted.
# A health check that cannot fail isn't a health check.
#
# Deliberately checks the DATABASE ONLY. Stripe, R2 and the fonts CDN are all
# things the site degrades gracefully without, and failing health on a
# third-party blip would pull the whole service out of rotation over something
# it could have ridden out.
#
# Inherits from ActionController::Base rather than ApplicationController so
# nothing app-wide — Pundit, allow_browser, flash — sits between a monitor and
# its answer.
class HealthController < ActionController::Base
  # A monitor isn't a browser and has no session or CSRF token.
  skip_forgery_protection

  def show
    ActiveRecord::Base.connection.select_value("SELECT 1")
    render plain: "ok", status: :ok
  rescue StandardError => e
    # Logged at error so it lands wherever the app's logs are read; the status
    # code is what actually takes the instance out of rotation.
    Rails.logger.error("Health check FAILED: #{e.class}: #{e.message}")
    render plain: "database unavailable", status: :service_unavailable
  end
end
