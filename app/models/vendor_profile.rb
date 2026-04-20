class VendorProfile < ApplicationRecord
  belongs_to :user

  validates :vendor_id, presence: true, uniqueness: true
  validates :stall_name, presence: true

  before_validation :generate_vendor_id, on: :create

  private

  def generate_vendor_id
    self.vendor_id ||= "VND#{SecureRandom.random_number(10000).to_s.rjust(4, '0')}"
  end
end
