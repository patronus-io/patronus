class SessionsController < ApplicationController
  def create
    github_authenticate!
    User.find_or_create_by!(username: github_user.username)
    redirect_to profile_path
  end

  def destroy
    github_logout
    redirect_to root_path
  end
end
