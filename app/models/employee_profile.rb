class EmployeeProfile < ApplicationRecord
  belongs_to :user

  validates :employee_id, presence: true, uniqueness: true
  validates :department,  presence: true

  DEPARTMENTS = %w[Engineering Design Marketing HR Finance Operations Sales].freeze

  before_validation :generate_employee_id, on: :create

  private

  def generate_employee_id
    self.employee_id ||= "EMP#{SecureRandom.random_number(100000).to_s.rjust(5, '0')}"
  end
end
