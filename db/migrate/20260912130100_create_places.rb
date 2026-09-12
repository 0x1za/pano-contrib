class CreatePlaces < ActiveRecord::Migration[8.1]
  def change
    create_table :places, id: :string do |t|
      t.references :gazetteer_version, null: false, foreign_key: true, type: :string
      t.integer :tier, null: false
      t.string :code, null: false
      t.string :parent_code
      t.string :name
      t.float :centroid_lat, null: false
      t.float :centroid_lng, null: false
      t.integer :structures, null: false, default: 0
    end
    add_index :places, [ :gazetteer_version_id, :code ], unique: true
    add_index :places, [ :gazetteer_version_id, :tier ]
  end
end
