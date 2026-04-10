class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :lockable, :trackable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  enum :role, { employee: 0, vendor: 1, admin: 2 }

  has_many :orders,             dependent: :destroy
  has_many :otp_verifications,  dependent: :destroy
  has_one  :employee_profile,   dependent: :destroy
  has_one  :vendor_profile,     dependent: :destroy

  validates :name,  presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :role,  presence: true

  scope :active,    -> { where(active: true) }
  scope :employees, -> { where(role: :employee) }
  scope :vendors,   -> { where(role: :vendor) }
  scope :admins,    -> { where(role: :admin) }

  before_create :set_defaults

  # ── Google OAuth ──────────────────────────────────────────────────
  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_initialize.tap do |user|
      user.email        = auth.info.email
      user.name         = auth.info.name
      user.avatar_url   = auth.info.image
      user.role       ||= :employee
      user.active       = true
      user.confirmed_at = Time.current
      user.password     = Devise.friendly_token[0, 20] if user.encrypted_password.blank?
      user.save!
    end
  end

  def self.find_or_create_for_google(auth)
    user = find_by(provider: auth.provider, uid: auth.uid) ||
           find_by(email: auth.info.email)

    if user
      user.update(
        provider:   auth.provider,
        uid:        auth.uid,
        avatar_url: auth.info.image,
        confirmed_at: user.confirmed_at || Time.current
      )
      user
    else
      from_omniauth(auth)
    end
  end

  # ── Password setup ────────────────────────────────────────────────
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
