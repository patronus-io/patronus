class SessionsController < ApplicationController
  def create
    github_authenticate!
    redirect_to profile_path
  end

  def destroy
    github_logout
    redirect_to root_path
  end
end
