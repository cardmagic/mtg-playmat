class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :ensure_playmat_session

  helper_method :playmat_session_id

  private

  def ensure_playmat_session
    return if playmat_session_id.present?

    cookies.signed.permanent[Playmat::SESSION_COOKIE] = {
      value: SecureRandom.uuid,
      httponly: true,
      same_site: :lax,
      secure: Rails.env.production?
    }
  end

  def playmat_session_id
    cookies.signed[Playmat::SESSION_COOKIE]
  end

  def playmat_authorization(room_code)
    Playmat::Authorization.new(room_code:, session_id: playmat_session_id)
  end
end
