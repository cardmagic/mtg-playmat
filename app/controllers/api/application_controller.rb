class Api::ApplicationController < ApplicationController
  after_action :prevent_caching

  rescue_from Archidekt::Error, with: :archidekt_unavailable
  rescue_from SolidObjects::Error, with: :solid_objects_unavailable

  private

  def prevent_caching
    response.headers["Cache-Control"] = "no-store"
  end

  def archidekt_unavailable(error)
    Rails.logger.error(error.full_message)
    render json: { error: "Archidekt is unavailable" }, status: :bad_gateway
  end

  def solid_objects_unavailable(error)
    Rails.logger.error(error.full_message)
    render json: { error: "The playmat is temporarily unavailable" }, status: :service_unavailable
  end
end
