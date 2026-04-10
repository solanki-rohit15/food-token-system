class Users::SessionsController < Devise::SessionsController
  def create
    super do |resource|
      if resource.persisted?
        flash[:notice] = "Welcome back, #{resource.name}!"
      end
    end
  end

  protected

  def after_sign_in_path_for(resource)
    resource.dashboard_path
  end
end
