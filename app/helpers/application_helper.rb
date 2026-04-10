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
      content_tag(:span, class: "badge bg-success") { "✅ Redeemed" }
    elsif token.expired?
      content_tag(:span, class: "badge bg-danger") { "⏰ Expired" }
    else
      content_tag(:span, class: "badge bg-warning text-dark") { "⏳ Active" }
    end
  end

  def role_badge(role)
    colors = { "admin" => "danger", "vendor" => "info", "employee" => "success" }
    color  = colors[role.to_s] || "secondary"
    content_tag(:span, role.to_s.capitalize, class: "badge bg-#{color}")
  end

  def format_time(time)
    time&.strftime("%I:%M %p") || "—"
  end

  def format_date(date)
    date&.strftime("%d %b %Y") || "—"
  end
end

  def nav_link(label, path, icon)
    active = current_page?(path) || request.path.start_with?(path.split("?").first)
    classes = ["nav-link ft-nav-link", active ? "active" : nil].compact.join(" ")
    link_to(path, class: classes) do
      content_tag(:i, "", class: "bi #{icon} me-1") + label
    end
  end

  def role_color(role)
    { "admin" => "danger", "vendor" => "info", "employee" => "success" }.fetch(role.to_s, "secondary")
  end
