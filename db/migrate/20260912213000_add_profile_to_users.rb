class AddProfileToUsers < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      t.string :display_name
      t.integer :role, null: false, default: 0
      t.integer :reputation, null: false, default: 0
      t.datetime :last_seen_at
    end
    add_index :users, :role
  end
end
