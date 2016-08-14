class GithubWebHookController
  class PullRequest < Event
    def run!
      if payload.action.eql? 'closed' && payload.pull_request.merged
        closed_and_merged
      else
        raise WebHookParametersError.new(msg: 'Invalid pull request', action: payload.action, 'pull_request.merged': payload.pull_request.merged)
      end
    end

    private

    def closed_and_merged
      pull_request = payload.pull_request
      port_branch_base = pull_request.base.ref
      port_branches = repo.port_branches.where(base: port_branch_base)

      port_branches.each do |port_branch|
        port_branch_dev = port_branch.dev
        head_sha = pull_request.head.sha

        feature_branch = if repo_name.eql? pull_request.head.repo.full_name
          pull_request.head.label
        else
          branch_name = "patronus-pr-#{port_branch_dev}-#{pull_request.number}"
          bot_client.create_ref(repo_name, "heads/#{branch_name}", head_sha)
          branch_name
        end

        bot_client.create_pull_request(repo_name, port_branch_dev, feature_branch, "[port] #{pull_request.title}", <<-MSG.strip_heredoc)
          Introduces changes from pull request ##{pull_request.number} into development branch `#{port_branch_dev}`.

          *Original pull request's description:*
          #{pull_request.body}
        MSG
      end
    end

    def init_msg
      Rails.logger.info { 'Github hook handler: pull_request' }
    end
  end
end