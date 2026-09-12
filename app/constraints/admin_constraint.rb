# Routing gate for admin-only mounts (Avo, the Flipper dashboard). Resolves
# the app's own signed session cookie to a user and checks the role, so a
# non-admin or signed-out request simply does not match the route (404).
class AdminConstraint
  def matches?(request)
    session_id = request.cookie_jar.signed[:session_id]
    session_id.present? && Session.find_by(id: session_id)&.user&.role_admin?
  end
end
