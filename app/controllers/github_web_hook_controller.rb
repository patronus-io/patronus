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
    pull_request = bot_client.pull_request(repo_name, pull_request)
    combined_status = bot_client.combined_status(repo_name, payload.commit.sha)
    parent_patronus_status = bot_client.statuses(repo_name, parent).find { |s| s.context = STATUS_CONTEXT }
    Rails.logger.info { "  -> combined: #{combined_status.state}, patronus: #{parent_patronus_status.state}" }
    case combined_status.state
    when "success", "failure"
      unless parent_patronus_status.state == "failure"
        bot_client.create_status(repo_name, parent, combined_status.state, context: STATUS_CONTEXT)
      end
      if combined_status.state == "success" && bot_client.combined_status(repo_name, parent).state == "success" && %w(:+1: retry).include?(comment)
        bot_client.update_branch(repo_name, pull_request.base.ref, payload.commit.sha, false)
        if pull_request.head.repo.full_name == repo_name
          bot_client.delete_branch(repo_name, pull_request.head.ref) rescue nil
        end
      end
      bot_client.delete_branch(repo_name, "patronus/#{parent}") rescue nil
    else
      # wait until all done
    end
  end

  def handle_issue_comment
    if payload["issue"]["state"] == "closed"
      handle_closed_issue
    else
      handle_issue
    end
  end

  def handle_pull_request
    return unless payload.action.eql? 'closed'
    pull_request = payload.pull_request
    return unless payload.pull_request and pull_request.merged

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

  private

  def handle_closed_issue
    return if ENV["CLOSED_ISSUE_DAY_LIMIT"].nil?

    today = DateTime.now
    Rails.logger.info { "-> closed_at: #{payload["issue"]["closed_at"]}" }
    Rails.logger.info { "-> closed_at type: #{payload["issue"]["closed_at"].class}" }
    closed_at = DateTime.parse(payload["issue"]["closed_at"].to_s)
    # Show warnings only if the issue has been closed for the limit time
    return if (today - closed_at).to_i < ENV["CLOSED_ISSUE_DAY_LIMIT"].to_i

    commenter = payload["comment"]["user"]["login"]
    bot = bot_client.user.login
    # Let the bot and collaborators comment freely
    return if commenter == bot || bot_client.collaborator?(repo_name, commenter)

    issue_number = payload["issue"]["number"]
    repo = Repo.find_by(name: repo_name)
    issue = Issue.find_by(number: issue_number)

    if issue.nil?
      issue = Issue.new(repo_id: repo.id, number: issue_number, comments_after_closed: 1)
      issue.save
    end

    comments = issue.comments_after_closed
    message = if comments == 2
                ENV["CLOSED_ISSUE_WARN_MESSAGE_2"]
              elsif comments > 2
                # Lock issue this way until octokit support it.
                # See https://github.com/octokit/octokit.rb/pull/770/files
                require "http"
                token = "access_token=#{bot_client.access_token}"
                uri = "https://api.github.com/repos/#{repo_name}/issues/#{issue_number}/lock?#{token}"

                # https://developer.github.com/v3/issues/#lock-an-issue
                HTTP.headers("Content-Length" => 0).put(uri)

                "Locking issue."
              else
                ENV["CLOSED_ISSUE_WARN_MESSAGE_1"]
              end

    bot_client.add_comment(repo_name, issue_number, message)
    issue.comments_after_closed += 1
    issue.save
  end

  def handle_issue
    return unless payload.action.eql? 'created'
    commenter = payload.comment.user.login
    return unless bot_client.collaborator?(repo_name, commenter)
    comment = payload.comment.body
    return unless comment.gsub!(/\Apatronus: /, "")
    comment.strip!
    issue_number = payload.issue.number
    return unless pull_request = bot_client.pull_request(repo_name, issue_number)
    head = pull_request.head.sha

    Rails.logger.info { "-> PR #{issue_number} - #{commenter}: #{comment.inspect}, HEAD #{head[0, 7]}" }

    case comment
    when ":+1:", "test", "retry"
      test_branch = "patronus/#{head}"
      Rails.logger.info { "  -> Creating pending status on PR HEAD" }
      bot_client.create_status(repo_name, head, "pending", context: STATUS_CONTEXT)
      Rails.logger.info { "  -> Creating test ref #{test_branch.inspect} based on #{pull_request.base.sha[0, 7]}" }
      target_branch = bot_client.branch(repo_name, pull_request.base.ref)
      bot_client.create_ref(repo_name, "heads/#{test_branch}", target_branch.commit.sha)
      message = <<-MSG.strip_heredoc
        Auto merge of PR ##{issue_number} by patronus from #{head} onto #{pull_request.base.label}
        #{commenter} => #{comment}
      MSG
      Rails.logger.info { "  -> Merging PR HEAD into test branch" }
      bot_client.merge(repo_name, test_branch, head, commit_message: message)
    when ":-1:"
      Rails.logger.info { "  -> Creating failure status on PR HEAD" }
      bot_client.create_status(repo_name, head, "failure", context: STATUS_CONTEXT)
    when "fork"
      Rails.logger.info { "  -> Creating a local branch from PR HEAD" }
      bot_client.create_ref(repo_name, "heads/patronus-pr-#{issue_number}", head)
    end
  end

  def verify_signature(payload_body)
    secret = ENV['GITHUB_WEBHOOK_SECRET'.freeze]
    expected_signature = request.headers['X-HUB-SIGNATURE'.freeze] || ''
    return unless secret
    signature = 'sha1=' << OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), secret, payload_body)
    status = 401 && render(text: "Signatures didn't match!") unless Rack::Utils.secure_compare(signature, expected_signature)
  end

  attr_reader :user, :repo_name, :user_client, :payload, :repo, :reviewership
  def find_reviewership!(repo, sender)
    if sender.eql? ENV['GITHUB_BOT_USERNAME'.freeze]
      # fake user and reviewership for the bot
      @user = User.new(username: ENV['GITHUB_BOT_USERNAME'.freeze], github_token: ENV['GITHUB_BOT_TOKEN'.freeze])
      @repo = Repo.find_by_name repo
      @reviewership = Reviewership.new(user: @user, repo: @repo)
      @repo_name = repo
      @user_client = @user.github
    else
      @reviewership = Reviewership.joins(:user).where('users.username' => sender).joins(:repo).where('repos.name' => repo).first!
      @repo = @reviewership.repo
      @user = @reviewership.user
      @repo_name = repo
      @user_client = @user.github
    end
  end

  def app_client
    @app_client ||= Octokit::Client.new(client_id: ENV['GITHUB_CLIENT_ID'.freeze], client_secret: ENV['GITHUB_CLIENT_SECRET'.freeze])
  end

  def bot_client
    # uses bot account if it has permissions, otherwise uses user account
    @bot_client ||= begin
      if @user_client.collaborator?(@repo.name, ENV['GITHUB_BOT_USERNAME'.freeze])
        Octokit::Client.new(:access_token => ENV['GITHUB_BOT_TOKEN'.freeze])
      else
        Rails.logger.warn { 'Bot does not have permissions, using user account to interact' }
        @user_client
      end
    end
  end
end
