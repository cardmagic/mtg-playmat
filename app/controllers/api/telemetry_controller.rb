class Api::TelemetryController < Api::ApplicationController
  ALLOWED_ACTIONS = %w[draw_card play_from_hand toggle_tap].freeze
  ALLOWED_PHASES = %w[fetch response_json render total].freeze

  def create
    measurement = request.request_parameters["measurement"]
    measurement = measurement.to_unsafe_h if measurement.respond_to?(:to_unsafe_h)
    action_type = measurement.is_a?(Hash) && measurement["action_type"].to_s

    return head :bad_request unless ALLOWED_ACTIONS.include?(action_type)

    durations = measurement["durations"]
    return head :bad_request unless durations.respond_to?(:each_pair)

    attributes = durations.each_pair.each_with_object({}) do |(phase, duration), result|
      next unless ALLOWED_PHASES.include?(phase)

      value = Float(duration)
      next unless value.finite? && value >= 0

      result["playmat.client.#{phase}_ms"] = value.round(2)
    rescue ArgumentError, TypeError
      next
    end
    attributes["playmat.action.type"] = action_type
    attributes["playmat.client.origin"] = "browser"

    OpenTelemetry.tracer_provider.tracer("mtg-playmat").in_span(
      "playmat.browser_action",
      attributes:
    ) { head :no_content }
  end
end
