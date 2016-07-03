class ReposController < ApplicationController
  before_action :get_repo_from_params, only: :show
  before_action :set_user_client, only: :show

  def show
    @pull_requests = @user_client.pull_requests(@repo.name, state: 'open').map do |incomplete_pr|
      @user_client.pull_request(@repo.name, incomplete_pr.number)
    end

    @statuses = Hash.new
    @pull_requests.each do |pr|
      @statuses[pr.id] = @user_client.combined_status(@repo.name, pr.head.sha).state
    end
  end

  private

  def get_repo_from_params
    name = "#{params[:account_name]}/#{params[:repo_name]}"
    @repo = Repo.find_by_name(name) || Repo.new(name: name)
  end

  def set_user_client
    @user_client = Octokit::Client.new(:access_token => current_user.github_token)
  end
end
