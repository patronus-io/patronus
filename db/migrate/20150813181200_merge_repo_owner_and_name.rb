class MergeRepoOwnerAndName < ActiveRecord::Migration
  def change
    Repo.find_each{|r| r.update! name: [r.owner, r.name].join("/") }
    
    remove_column :repos, :owner
  end
end
