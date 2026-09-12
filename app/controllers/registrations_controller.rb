class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: t("flash.try_again_later") }
  before_action :require_signups

  def new
    return redirect_to root_path if authenticated?

    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      start_new_session_for @user
      redirect_to contributions_path, notice: t(".welcome")
    else
      render :new, status: :unprocessable_content
    end
  end

  private
    def user_params
      params.expect(user: [ :email_address, :password, :password_confirmation, :display_name ])
    end

    # Signups open per deployment through the :signups flag.
    def require_signups
      redirect_to new_session_path, alert: t("registrations.closed") unless feature?(:signups)
    end
end
