class ApplicationController < ActionController::Base
  include Authentication
  include DeviceIdentity

  allow_browser versions: :modern

  helper_method :current_gazetteer

  private
    def current_gazetteer
      @current_gazetteer ||= GazetteerVersion.current
    end
end
