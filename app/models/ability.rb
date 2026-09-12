# Contributors manage their own pending contributions, moderators review,
# admins manage everything. Reputation is not a permission.
class Ability
  include CanCan::Ability

  def initialize(user)
    return if user.nil?

    if user.role_admin?
      can :manage, :all
    else
      can :read, Contribution, user_id: user.id
      can :destroy, Contribution, user_id: user.id, status: "pending"
      can :review, Contribution if user.role_moderator?
      can :manage, User, id: user.id
    end
  end
end
