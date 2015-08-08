class User < ActiveRecord::Base
  has_many :repos

  def self.create_or_update_from_github!(github_user)
    with_token = User.create_with(github_token: github_user.token)
    user = with_token.find_or_create_by!(username: github_user.login)
    user.update!(github_token: github_user.token)
  end

end
