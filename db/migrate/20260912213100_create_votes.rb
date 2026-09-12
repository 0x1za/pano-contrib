class CreateVotes < ActiveRecord::Migration[8.1]
  def change
    create_table :votes, id: :string do |t|
      t.references :contribution, null: false, foreign_key: true, type: :string
      t.references :device, null: false, foreign_key: true, type: :string
      t.references :user, foreign_key: true, type: :string
      t.integer :stance, null: false

      t.timestamps
    end
    add_index :votes, %i[contribution_id device_id], unique: true
    add_index :votes, %i[contribution_id user_id], unique: true
  end
end
