class OtpVerification < ApplicationRecord
  belongs_to :user

  OTP_EXPIRY  = 10.minutes
  OTP_LENGTH  = 6

  before_create :generate_otp

  scope :valid,   -> { where("expires_at > ?", Time.current) }
  scope :unused,  -> { where(verified: false) }

  def self.generate_for(user)
    user.otp_verifications.unused.update_all(verified: true)
    create!(user: user, expires_at: OTP_EXPIRY.from_now)
  end

  def verify!(code)
    return false if expired? || verified?
    return false unless otp == code.to_s.strip

    update!(verified: true, verified_at: Time.current)
    true
  end

  def expired?
    expires_at < Time.current
  end

  def verified?
    verified
  end

  private

  def generate_otp
    self.otp = SecureRandom.random_number(10**OTP_LENGTH).to_s.rjust(OTP_LENGTH, "0")
  end
end
