class GithubWebHookController
  class Status < Event
    def run!
      regex = /\AAuto merge of PR #(\d+) by patronus from (#{GIT_SHA_PATTERN}).*\n\w+ => (.*)\Z/
      unless payload.commit.commit.message =~ regex
        raise WebHookParametersError.new(msg: 'Commit message did not match regex.', 'commit.message': payload.commit.commit.message)
      end

      pull_request = $1
      parent = $2
      comment = $3
      Rails.logger.info { "-> PR ##{pull_request}, Parent #{parent[0, 7]}, #{comment.inspect}" }

      pull_request = bot_client.pull_request(repo_name, pull_request)
      combined_status = bot_client.combined_status(repo_name, payload.commit.sha)
      parent_patronus_status = bot_client.statuses(repo_name, parent).find { |s| s.context = STATUS_CONTEXT }
      Rails.logger.info { "  -> combined: #{combined_status.state}, patronus: #{parent_patronus_status.state}" }

      if combined_status.state.eql? 'success'
        bot_client.create_status(repo_name, parent, combined_status.state, context: STATUS_CONTEXT)
        if bot_client.combined_status(repo_name, parent).state == 'success' && %w(:+1: retry).include?(comment)
          bot_client.update_branch(repo_name, pull_request.base.ref, payload.commit.sha, false)
          if pull_request.head.repo.full_name == repo_name
            bot_client.delete_branch(repo_name, pull_request.head.ref) rescue nil
          end
        end
        bot_client.delete_branch(repo_name, "patronus/#{parent}") rescue nil
      elsif combined_status.state.eql? 'failure'
        # TODO: should we set the status to failure?
        bot_client.delete_branch(repo_name, "patronus/#{parent}") rescue nil
      elsif combined_status.state.eql? 'pending'
        raise WebHookError.new('Waiting for a status other than pending')
      end

      Rails.logger.info { '-> Status!' }
    end

    private

    def init_msg
      Rails.logger.info { 'Github hook handler: status' }
    end
  end
end