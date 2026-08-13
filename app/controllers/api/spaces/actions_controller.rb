class Api::Spaces::ActionsController < Api::ApplicationController
  include RoomScoped

  def create
    action = request.request_parameters["action"]
    action = action.to_unsafe_h if action.respond_to?(:to_unsafe_h)

    trace_action(action) { handle_action(action) }
  end

  private

  def handle_action(action)
    if interactive_request?
      room_reference.async(authorization_context: room_authorization).apply_action(
        action:,
        session_id: playmat_session_id
      )
      return head :no_content
    end

    result = room_reference.sync(authorization_context: room_authorization).apply_action(
      action:,
      session_id: playmat_session_id
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

  def trace_action(action)
    action_type = action.is_a?(Hash) && (action["type"] || action[:type]).to_s
    return yield unless %w[draw_card play_from_hand toggle_tap].include?(action_type)

    OpenTelemetry.tracer_provider.tracer("mtg-playmat").in_span(
      "playmat.http_action",
      attributes: {
        "playmat.action.type" => action_type,
        "http.request.method" => request.request_method,
        "url.path" => request.path
      }
    ) { yield }
  end

  def interactive_request?
    return false if request.format.json?

    request.format.html? || request.format.turbo_stream? || request.headers["Prefer"] == "respond-async"
  end
end
