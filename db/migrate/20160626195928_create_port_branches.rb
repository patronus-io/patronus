class CreatePortBranches < ActiveRecord::Migration
  def change
    create_table :port_branches do |t|
      t.belongs_to :repo, index: true, foreign_key: true
      t.string :base
      t.string :dev

      t.timestamps null: false
    end
  end
end
