class SessionsController < ApplicationController
  def create
    github_authenticate!
    User.find_or_create_by!(username: github_user.login, github_token: github_user.token)
    redirect_to profile_path
  end

  def destroy
    github_logout
    redirect_to root_path
  end
end
