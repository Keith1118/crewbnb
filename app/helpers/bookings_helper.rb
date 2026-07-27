# Status badges appear on four booking screens (guest index/show, host
# index/show) and were copy-pasted case statements, so every new status meant
# four edits and a chance to miss one. Centralised here instead.
#
# Class names are spelled out in full rather than interpolated from a colour
# name — Tailwind scans source text for literal classes, and anything it can't
# see gets stripped from the build.
module BookingsHelper
  STATUS_STYLES = {
    "pending" => {
      base: "bg-yellow-100 text-yellow-800", border: "border-yellow-200",
      icon: "schedule", label: "Pending"
    },
    "awaiting_payment" => {
      base: "bg-orange-100 text-orange-800", border: "border-orange-200",
      icon: "credit_card", label: "Awaiting payment"
    },
    "confirmed" => {
      base: "bg-green-100 text-green-800", border: "border-green-200",
      icon: "check_circle", label: "Confirmed"
    },
    "cancelled" => {
      base: "bg-red-100 text-red-800", border: "border-red-200",
      icon: "cancel", label: "Cancelled"
    },
    "completed" => {
      base: "bg-blue-100 text-blue-800", border: "border-blue-200",
      icon: "task_alt", label: "Completed"
    }
  }.freeze

  # A status with no entry here must degrade to a plain badge, never to nil —
  # adding an enum value once left `case` statements returning nil and took the
  # host dashboard down with `undefined method [] for nil`.
  UNKNOWN_STYLE = {
    base: "bg-neutral-100 text-neutral-700", border: "border-neutral-200",
    icon: "help", label: nil
  }.freeze

  def booking_status_badge_classes(status, bordered: false)
    style = style_for(status)

    bordered ? "#{style[:base]} #{style[:border]}" : style[:base]
  end

  def booking_status_icon(status)
    style_for(status)[:icon]
  end

  def booking_status_label(status)
    style_for(status)[:label] || status.to_s.humanize
  end

  private

  def style_for(status)
    STATUS_STYLES.fetch(status.to_s, UNKNOWN_STYLE)
  end
end
