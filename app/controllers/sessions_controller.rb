class SessionsController < ApplicationController
  def create
    github_authenticate!
    User.create_or_update_from_github!(github_user)
    redirect_to profile_path
  end

  def destroy
    github_logout
    redirect_to root_path
  end
end
