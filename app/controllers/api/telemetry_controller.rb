class Api::TelemetryController < Api::ApplicationController
  ALLOWED_ACTIONS = %w[draw_card play_from_hand toggle_tap].freeze
  ALLOWED_EVENTS = %w[payload_refresh].freeze
  ALLOWED_PHASES = %w[fetch response_json render total].freeze

  def create
    measurement = request.request_parameters["measurement"]
    measurement = measurement.to_unsafe_h if measurement.respond_to?(:to_unsafe_h)
    return head :bad_request unless measurement.is_a?(Hash)

    action_type = measurement["action_type"].to_s
    event_type = measurement["event_type"].to_s
    return head :bad_request unless ALLOWED_ACTIONS.include?(action_type) || ALLOWED_EVENTS.include?(event_type)

    attributes = {
      "playmat.client.origin" => "browser"
    }

    if ALLOWED_ACTIONS.include?(action_type)
      durations = measurement["durations"]
      return head :bad_request unless durations.respond_to?(:each_pair)

      durations.each_pair do |phase, duration|
        next unless ALLOWED_PHASES.include?(phase)

        value = Float(duration)
        next unless value.finite? && value >= 0

        attributes["playmat.client.#{phase}_ms"] = value.round(2)
      rescue ArgumentError, TypeError
        next
      end
      attributes["playmat.action.type"] = action_type
    else
      attributes["playmat.client.event"] = event_type
      attributes["playmat.client.payload_version"] = measurement["payload_version"].to_i
      attributes["playmat.client.pending_actions"] = measurement["pending_actions"].to_i
    end

    OpenTelemetry.tracer_provider.tracer("mtg-playmat").in_span(
      ALLOWED_ACTIONS.include?(action_type) ? "playmat.browser_action" : "playmat.browser_payload",
      attributes:
    ) { head :no_content }
  end
end
