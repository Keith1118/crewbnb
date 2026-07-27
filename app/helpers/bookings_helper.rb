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

  def booking_status_badge_classes(status, bordered: false)
    style = STATUS_STYLES[status.to_s] or return nil

    bordered ? "#{style[:base]} #{style[:border]}" : style[:base]
  end

  def booking_status_icon(status)
    STATUS_STYLES.dig(status.to_s, :icon)
  end

  def booking_status_label(status)
    STATUS_STYLES.dig(status.to_s, :label) || status.to_s.humanize
  end
end
