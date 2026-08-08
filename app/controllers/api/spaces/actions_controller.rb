class Api::Spaces::ActionsController < Api::ApplicationController
  include RoomScoped

  def create
    action = request.request_parameters["action"]
    action = action.to_unsafe_h if action.respond_to?(:to_unsafe_h)
    result = room_reference.apply_action(
      action:,
      session_id: playmat_session_id,
      authorization_context: room_authorization
    )

    case result
    when "applied"
      render_room
    when "invalid"
      render json: { error: "Action payload is required" }, status: :bad_request
    when "forbidden"
      render json: { error: "You are not a player in this space" }, status: :forbidden
    else
      render json: { error: "Space not found" }, status: :not_found
    end
  end
end
