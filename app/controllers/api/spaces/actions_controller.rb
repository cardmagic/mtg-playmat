class Api::Spaces::ActionsController < Api::ApplicationController
  include RoomScoped

  def create
    action = request.request_parameters["action"]
    action = action.to_unsafe_h if action.respond_to?(:to_unsafe_h)

    if interactive_request?
      room_reference.async(
        :apply_action,
        action:,
        session_id: playmat_session_id,
        authorization_context: room_authorization
      )
      return head :no_content
    end

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

  private

  def interactive_request?
    return false if request.format.json?

    request.format.html? || request.format.turbo_stream? || request.headers["Prefer"] == "respond-async"
  end
end
