class Reviewership < ActiveRecord::Base
  belongs_to :user
  belongs_to :repo

  accepts_nested_attributes_for :repo

  def ensure_webhook_installed!
    hook_url = Rails.application.routes.url_helpers.url_for controller: "github_web_hook", action: "create", host: ENV['GITHUB_WEBHOOK_HOST']
    unless user.github.hooks(repo.name).find { |hook| hook.url == hook_url }
      config = { url: hook_url, content_type: :json, secret: ENV['GITHUB_WEBHOOK_SECRET'.freeze] }
      user.github.create_hook(repo.name, "web", config, { events: ["*"] })
    end
  end

  def ensure_bot_permissions!
    unless user.github.collaborator?(repo.name, ENV['GITHUB_BOT_USERNAME'])
      # adds bot to repo with push access, even on organization-owned repos
      user.github.add_collaborator(repo.name, ENV['GITHUB_BOT_USERNAME'])
    end
  end
end
