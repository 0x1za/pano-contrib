class CreateDevices < ActiveRecord::Migration[8.1]
  def change
    create_table :devices, id: :string do |t|
      t.string :token_digest, null: false, limit: 64
      t.references :user, foreign_key: true, type: :string
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false

      t.timestamps
    end
    add_index :devices, :token_digest, unique: true
  end
end
