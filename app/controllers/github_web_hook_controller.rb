class GithubWebHookController < ApplicationController
  require "openssl"

  GIT_SHA_PATTERN = /[a-f0-9]{40}/
  STATUS_CONTEXT = 'merge/patronus'.freeze

  protect_from_forgery with: :null_session

  def create
    event = request.headers['X-GitHub-Event'.freeze]
    body = request.body.read

    # parse request body
    render(text: 'Signatures did not match!', status: 401) unless valid_signature?(body)
    payload = app_client.parse_payload(body)

    # get reviewership
    repo_full_name = payload.try(:repository).try(:full_name)
    login = payload.try(:sender).try(:login)
    if repo_full_name && login
      begin
        find_reviewership!(repo_full_name, login)
      rescue ActiveRecord::RecordNotFound => error
        render text: error.message, status: 404
      end
    end

    # select and run the hook handler
    event_opt = payload, app_client, bot_client
    hook_handler = case event
      when 'ping'
        Ping.new *event_opt
      when 'status'
        Status.new *event_opt
      when 'issue_comment'
        IssueComment.new *event_opt
      when 'pull_request'
        PullRequest.new *event_opt
      else
        render text: "Unrecognized event `#{event}`", status: 501
    end

    begin
      hook_handler.run!
    rescue WebHookError => error
      render text: error.message, status: error.status
    end

    render text: 'Success!', status: 200 unless performed?
  end

  private

  def valid_signature?(payload_body)
    secret = ENV['GITHUB_WEBHOOK_SECRET'.freeze]
    expected_signature = request.headers['X-HUB-SIGNATURE'.freeze] || ''
    return false unless secret
    signature = 'sha1=' << OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), secret, payload_body)
    Rack::Utils.secure_compare(signature, expected_signature)
  end

  attr_reader :user, :repo_name, :user_client, :repo, :reviewership
  def find_reviewership!(repo, sender)
    if sender.eql? ENV['GITHUB_BOT_USERNAME'.freeze]
      # fake user and reviewership for the bot
      @user = User.new(username: ENV['GITHUB_BOT_USERNAME'.freeze], github_token: ENV['GITHUB_BOT_TOKEN'.freeze])
      @repo = Repo.find_by_name repo
      @reviewership = Reviewership.new(user: @user, repo: @repo)
      @user_client = @user.github
    else
      @reviewership = find_user_reviewership(repo, sender)
      @repo = @reviewership.repo
      @user = @reviewership.user
      @user_client = @user.github
    end
  end

  def find_user_reviewership(repo, sender)
    Reviewership.joins(:user).where('users.username' => sender).joins(:repo).where('repos.name' => repo).first!
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
