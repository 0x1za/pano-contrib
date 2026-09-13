class CreateSurveys < ActiveRecord::Migration[8.1]
  def change
    create_table :surveys, id: :string do |t|
      t.references :gazetteer_version, null: false, foreign_key: true, type: :string
      t.references :opened_by, null: false, foreign_key: { to_table: :users }, type: :string
      t.string :target_code, null: false
      t.string :target_name
      t.integer :goal, null: false, default: 10
      t.integer :status, null: false, default: 0
      t.datetime :closed_at
      t.text :notes

      t.timestamps
    end
    add_index :surveys, %i[gazetteer_version_id target_code]

    create_table :survey_responses, id: :string do |t|
      t.references :survey, null: false, foreign_key: true, type: :string
      t.references :recorded_by, null: false, foreign_key: { to_table: :users }, type: :string
      t.references :building, foreign_key: true, type: :string
      t.string :address
      t.boolean :recognises, null: false
      t.string :calls_it
      t.text :note

      t.timestamps
    end
  end
end
