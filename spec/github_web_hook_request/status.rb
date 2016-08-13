class GithubWebHookRequest
  class Status < GithubWebHookRequest

    # def initialize(request, body)
    #   @body = JSON.parse body
    #   super('status', request)
    # end

    # simple parameters:
    #   sha: '5b84c7138bbd1d46fa0768ab5d8f72116f5241b9'
    #   username: 'bundlerbot'
    #   user_id: 1234567
    #   repo_full_name: 'patronus-io/patronus'
    #   context: 'merge/patronus'
    #   state: 'Pending', 'Success' or 'Failure'
    # commit_params:
    #   all from #commit, :repo_full_name and :sha are already present and can be omitted
    # branches:
    #   array of #branch params, :repo_full_name and :sha are already present and can be omitted
    # repository_params:
    #   all from #repository, :username, :user_id, :repo_full_name and :user_is_organization are already present and can be omitted
    # sender_params:
    #   all from #user, :id (:user_id) and :username are already present and can be omitted
    def initialize(request: nil,
      id: 123456, sha:, username:, user_id:, user_is_organization: false, repo_full_name:, context:, state:,
      commit_params:, branches:, repository_params:, sender_params: {}
    )
      @body = {
        id: id,
        sha: sha,
        name: repo_full_name,
        target_url: nil,
        context: context,
        description: nil,
        state: state,
        commit: commit(
          repo_full_name: repo_full_name,
          sha: sha,
          **commit_params
        ),
        branches: branches.map do |branch_params|
          branch(
            sha: sha,
            repo_full_name: repo_full_name,
            **branch_params
          )
        end,
        created_at: '2016-07-20T13:28:58Z',
        updated_at: '2016-07-20T13:28:58Z',
        repository: repository(
          full_name: repo_full_name,
          username: username,
          user_id: user_id,
          user_is_organization: user_is_organization,
          **repository_params
        ),
        sender: user(
          id: user_id,
          username: username,
          **sender_params
        ),
      }
      super('status', request)
    end
  end
end