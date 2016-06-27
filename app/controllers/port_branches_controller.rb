class PortBranchesController < ApplicationController
  before_filter :set_repo, :only => :create

  def create
    if @repo && @port_branch = PortBranch.create(port_branch_params)
      @repo.port_branches << @port_branch
    end
    redirect_to(profile_path)
  end

  private

  def set_repo
    @repo = Repo.find(params[:repo_id])
  end

  def port_branch_params
    params.require(:port_branch).permit(:base, :dev)
  end
end
