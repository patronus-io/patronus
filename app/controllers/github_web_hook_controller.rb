class GithubWebHookController < ApplicationController
  require "openssl"

  GIT_SHA_PATTERN = /[a-f0-9]{40}/
  STATUS_CONTEXT = 'merge/patronus'.freeze

  protect_from_forgery with: :null_session

  def create
    event = request.headers['X_GITHUB_EVENT'.freeze]
    body = request.body.read
    verify_signature(body)

    @payload = app_client.parse_payload(body)
    self.repo = payload.repository.full_name
    method_for_event = :"handle_#{event}"
    status = 500 && render(text: "Unrecognized event `#{event}`") && return unless respond_to?(method_for_event)
    send(method_for_event)

    status = 200
    render text: ""
  end

  def handle_ping

  end

  def handle_status
    regex = /\AAuto merge of PR #(\d+) patronus from (#{GIT_SHA_PATTERN})[^$]$^\w+ (.*)\Z/m
    return unless payload.commit.message =~ regex
    pull_request = user_client.pull_request(repo, $1)
    parent = $2
    comment = $3
    combined_status = user_client.combined_status(repo, payload.commit.sha)
    parent_patronus_status = user_client.statuses(repo, parent).find { |s| s.content = STATUS_CONTEXT }
    case combined_status.state
    when "success", "failure"
      unless parent_patronus_status.state == "failure"
        user_client.create_status(repo, parent, combined_status.state, context: STATUS_CONTEXT)
      end
      if combined_status.state == "success" && user_client.combined_status(repo, parent).state == "success" && comment != 'test'
        user_client.update_branch(repo, pull_request.base.ref, payload.commit.sha, false)
      end
      user_client.delete_branch(repo, "patronus/#{parent}")
    else
      # wait until all done
    end
  end

  def handle_issue_comment
    return unless commenter = User.find_by(username: payload.comment.user.login)
    return unless project.users.include?(commenter)
    return unless comment = /\Apatronus: /
    issue_number = payload.issue.number
    return unless pull_request = user_client.pull_request(repo, issue_number)
    head = pull_request.head.sha
    test_branch = "patronus/#{head}"

    comment = comment[10..-1]
    case comment
    when ":+1:", "test", "retry"
      user_client.create_status(repo, head, "pending", context: STATUS_CONTEXT)
      user_client.create_branch(repo, "heads/#{test_branch}", pull_request.base.sha)
      message = <<-MSG.strip_heredoc
        Auto merge of PR ##{issue_number} by patronus from #{head} onto #{pull_request.base.label}
        #{commenter.username} => #{comment}
      MSG
      user_client.merge(repo, pull_request.base.ref, head, test_branch, commit_message: message)
    when ":-1:"
      user_client.create_status(repo, head, "failure", context: STATUS_CONTEXT)
    end
  end

  private

  def verify_signature(payload_body)
    secret = ENV['GITHUB_WEBHOOK_SECRET'.freeze]
    return unless secret
    signature = 'sha1=' << OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), secret, payload_body)
    status = 401 && render(text: "Signatures didn't match!") unless Rack::Utils.secure_compare(signature, request.header['HTTP_X_HUB_SIGNATURE'])
  end

  attr_reader :user, :project, :user_client, :payload, :repo
  def repo=(repo)
    @repo = repo
    @project = Project.find_by!(repo: repo)
    @user = @project.user
    @user_client = Octokit::Client.new(:access_token => @user.github_user.access_token)
  end

  def app_client
    @app_client ||= Octokit::Client.new(client_id: ENV["GITHUB_CLIENT_ID".freeze], client_secret: ENV["GITHUB_CLIENT_SECRET".freeze])
  end
end
