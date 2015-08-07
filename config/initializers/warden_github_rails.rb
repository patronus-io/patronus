Warden::GitHub::Rails.setup do |config|
  config.add_scope :user, redirect_uri: '/login', scope: 'user:email,read:org,write:repo_hook,repo'
end
