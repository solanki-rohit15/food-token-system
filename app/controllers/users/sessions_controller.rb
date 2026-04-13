class Users::SessionsController < Devise::SessionsController
  # after_sign_in_path_for is defined in ApplicationController
  # and handles must_change_password? redirect — do not override here
  def create
    super do |resource|
      flash[:notice] = "Welcome back, #{resource.name}!" if resource.persisted?
    end
  end
end
