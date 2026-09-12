class CreateGazetteerVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :gazetteer_versions, id: :string do |t|
      t.string :version, null: false
      t.string :sha256, null: false, limit: 64
      t.string :area, null: false
      t.integer :units_count, null: false, default: 0
      t.integer :buildings_count, null: false, default: 0
      t.json :names, null: false, default: {}
      t.datetime :imported_at, null: false

      t.timestamps
    end
    add_index :gazetteer_versions, :version, unique: true
    add_index :gazetteer_versions, :sha256, unique: true
  end
end
