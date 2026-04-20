module ApplicationHelper
  def time_of_day_greeting
    hour = Time.current.hour
    case hour
    when 5..11  then "morning"
    when 12..16 then "afternoon"
    when 17..20 then "evening"
    else             "evening"
    end
  end

  def token_status_badge(token)
    return content_tag(:span, "No Token", class: "badge bg-secondary") if token.nil?

    if token.redeemed?
      content_tag(:span, "✅ Redeemed", class: "badge bg-success")
    elsif token.expired?
      content_tag(:span, "⏰ Expired",  class: "badge bg-danger")
    else
      content_tag(:span, "⏳ Active",   class: "badge bg-warning text-dark")
    end
  end

  def role_badge(role)
    colors = { "admin" => "danger", "vendor" => "info", "employee" => "success" }
    color  = colors[role.to_s] || "secondary"
    content_tag(:span, role.to_s.capitalize, class: "badge bg-#{color}")
  end

  def format_time(time)  = time&.strftime("%I:%M %p") || "—"
  def format_date(date)  = date&.strftime("%d %b %Y") || "—"
  def role_color(role)   = { "admin" => "danger", "vendor" => "info", "employee" => "success" }.fetch(role.to_s, "secondary")

  def nav_link(label, path, icon)
    active  = current_page?(path) || request.path.start_with?(path.split("?").first)
    classes = ["nav-link ft-nav-link", active ? "active" : nil].compact.join(" ")
    link_to(path, class: classes) do
      content_tag(:i, "", class: "bi #{icon} me-1") + label
    end
  end

  def currency(amount)
    "₹#{format('%.2f', amount)}"
  end
end
