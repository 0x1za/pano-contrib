# Every visitor gets a device: a random token in a signed, long-lived
# cookie, stored as a digest. It is the identity anonymous contributions
# hang off, and what rack-attack throttles on.
module DeviceIdentity
  extend ActiveSupport::Concern

  COOKIE = :pano_device

  included do
    before_action :resume_device
  end

  private
    def resume_device
      Current.device = Device.find_by_token(cookies.signed[COOKIE])
      Current.device&.touch_seen!
    end

    def current_device
      Current.device || issue_device
    end

    def issue_device
      device, raw = Device.issue!
      cookies.signed.permanent[COOKIE] = { value: raw, httponly: true, same_site: :lax }
      Current.device = device
    end
end
