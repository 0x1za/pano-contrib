class Avo::Resources::Device < Avo::BaseResource
  self.icon = "tabler/outline/device-mobile"
  self.title = :id

  def fields
    field :id, as: :id
    field :user, as: :belongs_to
    field :first_seen_at, as: :date_time, readonly: true
    field :last_seen_at, as: :date_time, readonly: true
    field :contributions, as: :has_many
    field :votes, as: :has_many
  end
end
