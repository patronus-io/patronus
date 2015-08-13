class ReviewershipsController < ApplicationController
  def create
    Reviewership.create!(reviewership_params)
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
