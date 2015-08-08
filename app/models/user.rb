class User < ActiveRecord::Base
  has_many :repos

  def self.create_or_update_from_github!(github_user)
    user = User.find_or_create_by!(username: github_user.login, github_token: github_user.token)
    user.update!(github_token: github_user.token)
  end

end
