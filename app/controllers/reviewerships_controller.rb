class ReviewershipsController < ApplicationController
  def create
    Reviewership.create!(reviewership_params) do |reviewership|
      reviewership.ensure_webhook_installed!
      reviewership.ensure_bot_permissions!
    end
    redirect_to(profile_path)
  end

private

  def reviewership_params
    params.require(:reviewership).permit(repo: [:owner, :name]).tap do |p|
      p[:repo_attributes] = p.delete(:repo)
      p[:user] = current_user
    end
  end
end
