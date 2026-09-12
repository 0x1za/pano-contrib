class Avo::Resources::Contribution < Avo::BaseResource
  self.icon = "tabler/outline/message-2"
  self.title = :target_label
  self.search = { query: -> { query.where("target_code LIKE :q", q: "%#{q}%") } }

  def fields
    field :id, as: :id
    field :kind, as: :select, enum: ::Contribution.kinds, readonly: true
    field :status, as: :select, enum: ::Contribution.statuses
    field :target_kind, as: :select, enum: ::Contribution.target_kinds, readonly: true
    field :target_code, as: :text, readonly: true
    field :building, as: :belongs_to, readonly: true
    field :payload, as: :code, language: "json", readonly: true, format_using: -> { JSON.pretty_generate(value) }
    field :review_note, as: :textarea
    field :reviewed_by, as: :belongs_to
    field :reviewed_at, as: :date_time
    field :device, as: :belongs_to, readonly: true
    field :user, as: :belongs_to, readonly: true
    field :gazetteer_version, as: :belongs_to, readonly: true
    field :deleted_at, as: :date_time, readonly: true
    field :created_at, as: :date_time, hide_on: [ :forms ]
    field :votes, as: :has_many
  end
end
