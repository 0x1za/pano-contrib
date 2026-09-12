class Avo::Resources::Changeset < Avo::BaseResource
  self.icon = "tabler/outline/package-export"
  self.title = :id

  def fields
    field :id, as: :id
    field :status, as: :select, enum: ::Changeset.statuses, readonly: true
    field :gazetteer_version, as: :belongs_to, readonly: true
    field :summary, as: :code, language: "json", readonly: true, format_using: -> { JSON.pretty_generate(value) }
    field :exported_at, as: :date_time, readonly: true
    field :exported_by, as: :belongs_to, readonly: true
    field :applied_in_version, as: :text, readonly: true
    field :applied_at, as: :date_time, readonly: true
    field :contributions, as: :has_many
  end
end
