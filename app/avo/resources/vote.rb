class Avo::Resources::Vote < Avo::BaseResource
  self.icon = "tabler/outline/thumb-up"

  def fields
    field :id, as: :id
    field :stance, as: :select, enum: ::Vote.stances, readonly: true
    field :contribution, as: :belongs_to, readonly: true
    field :device, as: :belongs_to, readonly: true
    field :user, as: :belongs_to, readonly: true
    field :created_at, as: :date_time, hide_on: [ :forms ]
  end
end
