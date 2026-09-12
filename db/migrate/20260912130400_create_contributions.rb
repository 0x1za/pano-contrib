class CreateContributions < ActiveRecord::Migration[8.1]
  def change
    create_table :contributions, id: :string do |t|
      t.integer :kind, null: false
      t.integer :status, null: false, default: 0
      t.references :gazetteer_version, null: false, foreign_key: true, type: :string
      t.integer :target_kind, null: false
      t.string :target_code
      t.references :building, foreign_key: true, type: :string
      t.float :lat
      t.float :lng
      t.json :payload, null: false, default: {}
      t.references :device, null: false, foreign_key: true, type: :string
      t.references :user, foreign_key: true, type: :string
      t.references :reviewed_by, foreign_key: { to_table: :users }, type: :string
      t.datetime :reviewed_at
      t.text :review_note
      t.string :mutation_id, null: false
      t.datetime :deleted_at
      t.integer :version, null: false, default: 1

      t.timestamps
    end
    add_index :contributions, [ :device_id, :mutation_id ], unique: true
    add_index :contributions, [ :status, :kind ]
    add_index :contributions, :target_code
  end
end
