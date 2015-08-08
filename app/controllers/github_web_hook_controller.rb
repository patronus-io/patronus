class GithubWebHookController < ApplicationController
  require "openssl"

  GIT_SHA_PATTERN = /[a-f0-9]{40}/
  STATUS_CONTEXT = 'merge/patronus'.freeze

  protect_from_forgery with: :null_session

  def create
    event = request.headers['X-GitHub-Event'.freeze]
    body = request.body.read
    verify_signature(body)

    @payload = app_client.parse_payload(body)
    self.repo = payload.repository.full_name

    Rails.logger.info { "GitHub: #{repo_name} - #{event}" }

    method_for_event = :"handle_#{event}"
    if respond_to?(method_for_event)
      send(method_for_event)
      status = 200
      render text: "Success!"
    else
      status = 500
      render text: "Unrecognized event `#{event}`"
    end
  end

  def handle_ping
    Rails.logger.info { "-> Ping!" }
  end

  def handle_status
    regex = /\AAuto merge of PR #(\d+) by patronus from (#{GIT_SHA_PATTERN}).*\n\w+ => (.*)\Z/
    return unless payload.commit.commit.message =~ regex
    pull_request = $1
    parent = $2
    comment = $3
    Rails.logger.info { "-> PR ##{pull_request}, Parent #{parent[0, 7]}, #{comment.inspect}" }
    pull_request = user_client.pull_request(repo, pull_request)
    combined_status = user_client.combined_status(repo_name, payload.commit.sha)
    parent_patronus_status = user_client.statuses(repo_name, parent).find { |s| s.context = STATUS_CONTEXT }
    Rails.logger.info { "  -> combined: #{combined_status.state}, patronus: #{parent_patronus_status.state}" }
    case combined_status.state
    when "success", "failure"
      unless parent_patronus_status.state == "failure"
        user_client.create_status(repo_name, parent, combined_status.state, context: STATUS_CONTEXT)
      end
      if combined_status.state == "success" && user_client.combined_status(repo_name, parent).state == "success" && %w(:+1: retry).include?(comment)
        user_client.update_branch(repo_name, pull_request.base.ref, payload.commit.sha, false)
        if pull_request.head.repo.full_name == repo_name
          user_client.delete_branch(repo_name, pull_request.head.ref)
        end
      end
      user_client.delete_branch(repo_name, "patronus/#{parent}")
    else
      # wait until all done
    end
  end

  def handle_issue_comment
    commenter = payload.comment.user.login
    return unless user_client.collaborator?(repo_name, commenter)
    comment = payload.comment.body
    return unless comment.gsub!(/\Apatronus: /, "")
    comment.strip!
    issue_number = payload.issue.number
    return unless pull_request = user_client.pull_request(repo_name, issue_number)
    head = pull_request.head.sha
    test_branch = "patronus/#{head}"

    Rails.logger.info { "-> PR #{issue_number} - #{commenter}: #{comment.inspect}, HEAD #{head[0, 7]}" }

    case comment
    when ":+1:", "test", "retry"
      Rails.logger.info { "  -> Creating pending status on PR HEAD" }
      user_client.create_status(repo_name, head, "pending", context: STATUS_CONTEXT)
      Rails.logger.info { "  -> Creating test ref #{test_branch.inspect} based on #{pull_request.base.sha[0, 7]}" }
      user_client.create_ref(repo_name, "heads/#{test_branch}", pull_request.base.sha)
      message = <<-MSG.strip_heredoc
        Auto merge of PR ##{issue_number} by patronus from #{head} onto #{pull_request.base.label}
        #{commenter} => #{comment}
      MSG
      Rails.logger.info { "  -> Merging PR HEAD into test branch" }
      user_client.merge(repo_name, test_branch, head, commit_message: message)
    when ":-1:"
      Rails.logger.info { "  -> Creating failure status on PR HEAD" }
      user_client.create_status(repo_name, head, "failure", context: STATUS_CONTEXT)
    end
  end

  private

  def verify_signature(payload_body)
    secret = ENV['GITHUB_WEBHOOK_SECRET'.freeze]
    expected_signature = request.headers['X-HUB-SIGNATURE'.freeze]
    return unless secret
    signature = 'sha1=' << OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), secret, payload_body)
    status = 401 && render(text: "Signatures didn't match!") unless Rack::Utils.secure_compare(signature, expected_signature)
  end

  attr_reader :user, :repo_name, :user_client, :payload, :repo
  def repo=(repo)
    @repo_name = repo
    @repo = Repo.find_by!(name: repo)
    @user = @repo.user
    @user_client = Octokit::Client.new(:access_token => @user.github_token)
  end

  def app_client
    @app_client ||= Octokit::Client.new(client_id: ENV["GITHUB_CLIENT_ID".freeze], client_secret: ENV["GITHUB_CLIENT_SECRET".freeze])
  end
end
