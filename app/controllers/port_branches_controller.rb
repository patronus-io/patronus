class PortBranchesController < ApplicationController
  def create
    if @repo = Repo.find(params[:repo_id])
      if @port_branch = PortBranch.create(port_branch_params)
        @repo.port_branches << @port_branch
      end
    end
    redirect_to(profile_path)
  end

  private

  def port_branch_params
    params.require(:port_branch).permit(:base, :dev)
  end
end
