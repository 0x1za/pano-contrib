class Avo::Resources::Place < Avo::BaseResource
  self.icon = "tabler/outline/map-pin"
  self.title = :display_name
  self.search = { query: -> { query.where("code LIKE :q OR name LIKE :q", q: "%#{q}%") } }

  def fields
    field :id, as: :id
    field :code, as: :text, readonly: true
    field :tier, as: :select, enum: ::Place.tiers, readonly: true
    field :name, as: :text, readonly: true
    field :parent_code, as: :text, readonly: true
    field :structures, as: :number, readonly: true
    field :gazetteer_version, as: :belongs_to, readonly: true
  end
end
