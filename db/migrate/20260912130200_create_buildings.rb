class CreateBuildings < ActiveRecord::Migration[8.1]
  def change
    create_table :buildings, id: :string do |t|
      t.references :gazetteer_version, null: false, foreign_key: true, type: :string
      t.bigint :ingest_id, null: false
      t.string :unit_code, null: false
      t.integer :number, null: false
      t.float :lat, null: false
      t.float :lng, null: false
    end
    add_index :buildings, [ :gazetteer_version_id, :ingest_id ], unique: true
    add_index :buildings, [ :gazetteer_version_id, :unit_code, :number ], unique: true
  end
end
