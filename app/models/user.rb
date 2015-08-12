class User < ActiveRecord::Base
  has_many :repos

  def self.create_or_update_from_github!(github_user)
    with_token = User.create_with(github_token: github_user.token)
    user = with_token.find_or_create_by!(username: github_user.login)
    user.tap{|u| u.update!(github_token: github_user.token) }
  end

  def profile_url
    github_info.rels[:html].href
  end

  def avatar_url
    github_info.rels[:avatar].href
  end

  def github_info
    @github_info ||= github.user(username)
  end

  def github
    @github ||= Octokit::Client.new(:access_token => github_token)
  end

end
