class DropOtpVerifications < ActiveRecord::Migration[8.1]
  def change
    drop_table :otp_verifications, if_exists: true
  end
end
