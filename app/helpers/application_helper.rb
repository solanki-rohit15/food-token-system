module ApplicationHelper
  def time_of_day_greeting
    case Time.current.hour
    when 5..11  then "morning"
    when 12..16 then "afternoon"
    when 17..20 then "evening"
    else             "evening"
    end
  end

  def token_status_badge(token)
    case token.status
    when "redeemed"
      content_tag(:span, "✅ Redeemed", class: "badge bg-success-subtle text-success border border-success-subtle")
    when "expired"
      content_tag(:span, "⏰ Expired",  class: "badge bg-danger-subtle  text-danger  border border-danger-subtle")
    when "active"
      content_tag(:span, "⏳ Active",   class: "badge bg-warning-subtle text-warning border border-warning-subtle")
    else
      content_tag(:span, token.status.humanize, class: "badge bg-secondary")
    end
  end

  # Formats a number as Indian Rupees: ₹120.00
  def currency(amount)
    number_to_currency(amount, unit: "₹")
  end

  def nav_link(label, path, icon)
    active  = current_page?(path) || request.path.start_with?(path.split("?").first)
    classes = [ "nav-link ft-nav-link", active ? "active" : nil ].compact.join(" ")
    link_to(path, class: classes) do
      content_tag(:i, "", class: "bi #{icon} me-1") + " " + label
    end
  end

  def role_badge(role)
    case role.to_s
    when "admin"
      content_tag(:span, "Admin", class: "badge bg-dark")
    when "employee"
      content_tag(:span, "Employee", class: "badge bg-primary")
    when "vendor"
      content_tag(:span, "Vendor", class: "badge bg-info text-dark")
    else
      content_tag(:span, role.to_s.humanize, class: "badge bg-secondary")
    end
  end
end
