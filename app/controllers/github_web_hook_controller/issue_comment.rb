class GithubWebHookController
  class IssueComment < Event
    def run!
      repo_full_name = payload.repository.full_name

      if payload.action.eql? 'created'
        # authorization
        commenter = payload.comment.user.login
        unless bot_client.collaborator?(repo_full_name, commenter)
          raise WebHookError.new("User `#{commenter}` is not a collaborator on `#{repo_full_name}`", 401)
        end

        # comment pattern
        comment = payload.comment.body
        unless comment.gsub!(/\Apatronus: /, '')
          raise WebHookParametersError.new(msg: 'Invalid comment message', 'payload.comment.body': payload.comment.body)
        end
        comment.strip!

        # get pull request info
        pull_request_number = payload.issue.number
        unless pull_request = bot_client.pull_request(repo_full_name, pull_request_number)
          raise WebHookError.new("Could not fetch pull request ##{pull_request_number}", 404)
        end

        patronus_action_comment(
          pull_request: pull_request,
          pull_request_number: pull_request_number,
          commenter: commenter,
          comment: comment,
          repo_full_name: repo_full_name,
        )
      else
        raise WebHookParametersError.new(msg: 'Unrecognized action', 'action': payload.action, 'comment.body': payload.comment.body)
      end
    end

    private

    def patronus_action_comment(pull_request:, pull_request_number:, commenter:, comment:, repo_full_name:)
      head = pull_request.head.sha

      Rails.logger.info { "-> PR #{pull_request_number} - #{commenter}: #{comment.inspect}, HEAD #{head[0, 7]}" }

      case comment
        when ':+1:', 'test', 'retry'
          test_branch = "patronus/#{head}"

          Rails.logger.info { '  -> Creating pending status on PR HEAD' }
          bot_client.create_status(repo_full_name, head, 'pending', context: STATUS_CONTEXT)

          Rails.logger.info { "  -> Creating test ref #{test_branch.inspect} based on #{pull_request.base.sha[0, 7]}" }
          target_branch = bot_client.branch(repo_full_name, pull_request.base.ref)
          bot_client.create_ref(repo_full_name, "heads/#{test_branch}", target_branch.commit.sha)
          message = <<-MSG.strip_heredoc
            Auto merge of PR ##{pull_request_number} by patronus from #{head} onto #{pull_request.base.label}
            #{commenter} => #{comment}
          MSG

          Rails.logger.info { '  -> Merging PR HEAD into test branch' }
          bot_client.merge(repo_full_name, test_branch, head, commit_message: message)
        when ':-1:'
          Rails.logger.info { '  -> Creating failure status on PR HEAD' }
          bot_client.create_status(repo_full_name, head, 'failure', context: STATUS_CONTEXT)
        when 'fork'
          Rails.logger.info { '  -> Creating a local branch from PR HEAD' }
          bot_client.create_ref(repo_full_name, "heads/patronus-pr-#{pull_request_number}", head)
        else
          raise WebHookParametersError.new(msg: 'Invalid action in comment body', 'payload.comment.body': payload.comment.body)
      end
    end

    def init_msg
      Rails.logger.info { 'Github hook handler: issue_comment' }
    end
  end
end