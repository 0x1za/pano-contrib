# Admin back office. The /avo mount already sits behind AdminConstraint;
# authentication here re-checks inside the engine so it never trusts the
# router alone. Full config reference: https://docs.avohq.io
Avo.configure do |config|
  config.root_path = "/avo"
  config.app_name = "pano admin"

  config.current_user_method do
    Session.find_by(id: cookies.signed[:session_id])&.user
  end
  config.authenticate_with do
    raise ActionController::RoutingError, "Not Found" unless _current_user&.role_admin?
  end

  config.authorization_client = nil
  config.click_row_to_view_record = true
end
