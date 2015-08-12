class UsersController < ApplicationController
  def show
    @user = current_user
    @repos = current_user.repos
  end
end