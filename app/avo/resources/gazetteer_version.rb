class Avo::Resources::GazetteerVersion < Avo::BaseResource
  self.icon = "tabler/outline/map"
  self.title = :version

  def fields
    field :id, as: :id
    field :version, as: :text, readonly: true
    field :sha256, as: :text, readonly: true
    field :area, as: :text, readonly: true
    field :units_count, as: :number, readonly: true
    field :buildings_count, as: :number, readonly: true
    field :imported_at, as: :date_time, readonly: true
    field :contributions, as: :has_many
  end
end
