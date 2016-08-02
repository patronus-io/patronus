class CreateIssues < ActiveRecord::Migration
  def change
    create_table :issues do |t|
      t.belongs_to :repo, index: true, null: false, foreign_key: true
      t.integer :number
      t.integer :comments_after_closed
      t.timestamps null: false
    end
  end
end
