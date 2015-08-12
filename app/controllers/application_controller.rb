class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

private

  def current_user
    user = User.where(username: github_user.login).first
    user ||= User.create_or_update_from_github!(github_user)
  end

end
