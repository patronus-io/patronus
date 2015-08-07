class AddGithubTokenToUser < ActiveRecord::Migration
  def change
    add_column :users, :github_token, :string, null: false
  end
end
