class CreateRepos < ActiveRecord::Migration
  def change
    create_table :repos do |t|
      t.belongs_to :user
      t.string :name
    end
  end
end
