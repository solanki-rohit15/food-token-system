class User < ApplicationRecord
  ALLOWED_OAUTH_DOMAIN = ENV.fetch("GOOGLE_ALLOWED_DOMAIN", "ccube.com")

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :lockable, :trackable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  enum :role, { employee: 0, vendor: 1, admin: 2 }

  has_many :orders,            dependent: :destroy
  has_many :otp_verifications, dependent: :destroy
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

  # ── Google OAuth (domain-restricted) ──────────────────────────────
  def self.from_google_oauth(auth)
    email  = auth.info.email.to_s.downcase
    domain = email.split("@").last

    unless domain == ALLOWED_OAUTH_DOMAIN
      raise "Only @#{ALLOWED_OAUTH_DOMAIN} accounts are allowed to sign in with Google."
    end

    user = find_by(provider: auth.provider, uid: auth.uid) || find_by(email: email)

    if user
      user.update!(
        provider:     auth.provider,
        uid:          auth.uid,
        avatar_url:   auth.info.image,
        confirmed_at: user.confirmed_at || Time.current
      )
      user
    else
      create!(
        email:        email,
        name:         auth.info.name,
        avatar_url:   auth.info.image,
        provider:     auth.provider,
        uid:          auth.uid,
        role:         :employee,
        active:       true,
        confirmed_at: Time.current,
        password:     Devise.friendly_token[0, 20]
      )
    end
  end

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

  private

  def set_defaults
    self.active = true if active.nil?
    self.role   = :employee if role.nil?
  end
end
