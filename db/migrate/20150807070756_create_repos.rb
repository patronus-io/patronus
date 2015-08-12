class CreateRepos < ActiveRecord::Migration
  def change
    create_table :repos do |t|
      t.belongs_to :user
      t.string :name, null: false, unique: true
      t.timestamps null: false
    end
  end
end
