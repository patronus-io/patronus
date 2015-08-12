class CreateReviewerships < ActiveRecord::Migration
  def change
    create_table :reviewerships do |t|
      t.belongs_to :user, index: true, foreign_key: true
      t.belongs_to :repo, index: true, foreign_key: true
      t.timestamps null: false
    end
    
    remove_column :repos, :user_id
    add_column :repos, :owner, :string, null: false
  end
end
