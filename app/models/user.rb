class User < ApplicationRecord
  GOOGLE_WORKSPACE_DOMAIN = ENV.fetch("GOOGLE_WORKSPACE_DOMAIN", "ccube.com").downcase.freeze

  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :lockable, :trackable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  enum :role, { employee: 0, vendor: 1, admin: 2 }

  has_many :orders,            dependent: :destroy
  has_one  :employee_profile,  dependent: :destroy
  has_one  :vendor_profile,    dependent: :destroy

  validates :name,  presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :role,  presence: true

  scope :active,    -> { where(active: true) }
  scope :employees, -> { where(role: :employee) }
  scope :vendors,   -> { where(role: :vendor) }
  scope :admins,    -> { where(role: :admin) }

  before_create :set_defaults

  # ── First-login password change ────────────────────────────────────
  def must_change_password?
    must_change_password
  end

  def needs_password_setup?
    encrypted_password.blank? && provider.blank?
  end

  # ── Helpers ───────────────────────────────────────────────────────
  def initials
    name.split.map(&:first).first(2).join.upcase
  end

  def dashboard_path
    case role
    when "admin"    then Rails.application.routes.url_helpers.admin_root_path
    when "vendor"   then Rails.application.routes.url_helpers.vendor_root_path
    when "employee" then Rails.application.routes.url_helpers.employee_root_path
    else                 Rails.application.routes.url_helpers.root_path
    end
  end

  def active_token_today
    orders.today.joins(:token).merge(Token.active).first&.token
  end

  def today_order
    orders.today.includes(:food_items, :token).first
  end

  def ordered_today?
    orders.today.exists?
  end

  def self.from_google_oauth(auth)
    email = auth.dig("info", "email").to_s.strip.downcase
    unless allowed_google_domain?(email)
      Rails.logger.warn("[Google OAuth] Rejected unauthorized domain email=#{email.inspect}")
      return nil
    end

    user = where("LOWER(email) = ?", email).find_by(admin_created: true)
    unless user
      user_exists_without_admin_flag = where("LOWER(email) = ?", email).exists?
      Rails.logger.warn(
        "[Google OAuth] Rejected user email=#{email.inspect} "\
        "existing_user=#{user_exists_without_admin_flag} admin_created_required=true"
      )
      return nil
    end

    user.assign_attributes(
      provider: "google_oauth2",
      uid: auth["uid"],
      google_avatar_url: auth.dig("info", "image")
    )

    return user if user.save

    Rails.logger.warn("[Google OAuth] Could not update user email=#{email.inspect}: #{user.errors.full_messages.to_sentence}")
    nil
  end

  def self.allowed_google_domain?(email)
    domain = email.split("@").last.to_s.downcase
    domain == GOOGLE_WORKSPACE_DOMAIN
  end

  private

  def set_defaults
    self.active = true if active.nil?
    self.role   = :employee if role.nil?
  end
end
