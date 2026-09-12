class Avo::Resources::User < Avo::BaseResource
  self.icon = "tabler/outline/users"
  self.title = :email_address
  self.search = { query: -> { query.where("email_address LIKE :q OR display_name LIKE :q", q: "%#{q}%") } }

  def fields
    field :id, as: :id
    field :email_address, as: :text
    field :display_name, as: :text
    field :role, as: :select, enum: ::User.roles
    field :reputation, as: :number, readonly: true
    field :last_seen_at, as: :date_time, readonly: true
    field :created_at, as: :date_time, hide_on: [ :forms ]
    field :devices, as: :has_many
    field :contributions, as: :has_many
    field :votes, as: :has_many
  end
end
