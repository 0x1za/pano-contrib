class CreateChangesets < ActiveRecord::Migration[8.1]
  def change
    create_table :changesets, id: :string do |t|
      t.references :gazetteer_version, null: false, foreign_key: true, type: :string
      t.integer :status, null: false, default: 0
      t.json :summary, null: false, default: {}
      t.json :export, null: false, default: {}
      t.json :churn
      t.datetime :exported_at
      t.string :applied_in_version
      t.datetime :applied_at
      t.references :exported_by, foreign_key: { to_table: :users }, type: :string

      t.timestamps
    end
    add_index :changesets, %i[gazetteer_version_id status]
    add_reference :contributions, :changeset, foreign_key: true, type: :string
  end
end
