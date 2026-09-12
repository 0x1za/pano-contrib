class ApplicationController < ActionController::Base
  include Authentication
  include DeviceIdentity

  allow_browser versions: :modern

  helper_method :current_gazetteer, :current_user, :feature?

  # A denied ability reads as a missing page, never as a hint.
  rescue_from CanCan::AccessDenied do
    raise ActionController::RoutingError, "Not Found"
  end

  private
    def current_gazetteer
      @current_gazetteer ||= GazetteerVersion.current
    end

    def current_user
      Current.user
    end

    def feature?(name)
      Flipper.enabled?(name, Current.user)
    end

    def require_reviewer
      raise ActionController::RoutingError, "Not Found" unless current_user&.reviewer?
    end

    # Signing in or up claims the device the person was contributing from.
    def start_new_session_for(user)
      super.tap { user.claim!(Current.device) }
    end
end
