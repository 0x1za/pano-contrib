class Avo::Resources::Building < Avo::BaseResource
  self.icon = "tabler/outline/home"
  self.title = :address
  self.search = { query: -> { query.where("unit_code LIKE :q", q: "%#{q}%") } }

  def fields
    field :id, as: :id
    field :address, as: :text, readonly: true
    field :ingest_id, as: :number, readonly: true
    field :lat, as: :number, readonly: true
    field :lng, as: :number, readonly: true
    field :gazetteer_version, as: :belongs_to, readonly: true
    field :contributions, as: :has_many
  end
end
