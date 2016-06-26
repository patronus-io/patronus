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
    find_reviewership!(payload.repository.full_name, payload.sender.login)

    Rails.logger.info { "GitHub: #{repo_name} - #{event}" }

    method_for_event = :"handle_#{event}"
    if respond_to?(method_for_event)
      send(method_for_event)
      render text: "Success!", status: 200
    else
      render text: "Unrecognized event `#{event}`", status: 501
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
    pull_request = user_client.pull_request(repo_name, pull_request)
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
          user_client.delete_branch(repo_name, pull_request.head.ref) rescue nil
        end
      end
      user_client.delete_branch(repo_name, "patronus/#{parent}") rescue nil
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

    Rails.logger.info { "-> PR #{issue_number} - #{commenter}: #{comment.inspect}, HEAD #{head[0, 7]}" }

    case comment
    when ":+1:", "test", "retry"
      test_branch = "patronus/#{head}"
      Rails.logger.info { "  -> Creating pending status on PR HEAD" }
      user_client.create_status(repo_name, head, "pending", context: STATUS_CONTEXT)
      Rails.logger.info { "  -> Creating test ref #{test_branch.inspect} based on #{pull_request.base.sha[0, 7]}" }
      target_branch = user_client.branch(repo_name, pull_request.base.ref)
      user_client.create_ref(repo_name, "heads/#{test_branch}", target_branch.commit.sha)
      message = <<-MSG.strip_heredoc
        Auto merge of PR ##{issue_number} by patronus from #{head} onto #{pull_request.base.label}
        #{commenter} => #{comment}
      MSG
      Rails.logger.info { "  -> Merging PR HEAD into test branch" }
      user_client.merge(repo_name, test_branch, head, commit_message: message)
    when ":-1:"
      Rails.logger.info { "  -> Creating failure status on PR HEAD" }
      user_client.create_status(repo_name, head, "failure", context: STATUS_CONTEXT)
    when "fork"
      Rails.logger.info { "  -> Creating a local branch from PR HEAD" }
      user_client.create_ref(repo_name, "heads/patronus-pr-#{issue_number}", head)
    end
  end

  def handle_pull_request
    return unless payload.action.eql? 'closed'
    pull_request = payload.pull_request
    return unless payload.pull_request and pull_request.merged

    # TODO: check if the PR was merged into master (or some other branch obtained from config or db)
    dev_base = 'dev' # TODO: get this from config or db

    head_sha = pull_request.head.sha

    feature_branch = if repo_name.eql? pull_request.head.repo.full_name
      pull_request.head.label
    else
      branch_name = "patronus-pr-#{dev_base}-#{pull_request.number}"
      user_client.create_ref(repo_name, "heads/#{branch_name}", head_sha)
      branch_name
    end

    user_client.create_pull_request(repo_name, dev_base, feature_branch, "[port] #{pull_request.title}", <<-MSG.strip_heredoc)
      Introduces changes from pull request ##{pull_request.number} into development branch `#{dev_base}`.
      Original pull request's description:
      #{pull_request.body}
    MSG
  end

  private

  def verify_signature(payload_body)
    secret = ENV['GITHUB_WEBHOOK_SECRET'.freeze]
    expected_signature = request.headers['X-HUB-SIGNATURE'.freeze] || ''
    return unless secret
    signature = 'sha1=' << OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), secret, payload_body)
    status = 401 && render(text: "Signatures didn't match!") unless Rack::Utils.secure_compare(signature, expected_signature)
  end

  attr_reader :user, :repo_name, :user_client, :payload, :repo, :reviewership
  def find_reviewership!(repo, sender)
    @reviewership = Reviewership.joins(:user).where('users.username' => sender).joins(:repo).where('repos.name' => repo).first!
    @repo_name = repo
    @repo = @reviewership.repo
    @user = @reviewership.user
    @user_client = Octokit::Client.new(:access_token => @user.github_token)
  end

  def app_client
    @app_client ||= Octokit::Client.new(client_id: ENV["GITHUB_CLIENT_ID".freeze], client_secret: ENV["GITHUB_CLIENT_SECRET".freeze])
  end
end
