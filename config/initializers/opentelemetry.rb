require "opentelemetry"

if Rails.env.production? && ENV["HONEYBADGER_API_KEY"].present?
  require "opentelemetry/sdk"
  require "opentelemetry/exporter/otlp"

  OpenTelemetry::SDK.configure do |config|
    config.service_name = "mtg-playmat"
    config.add_span_processor(
      OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
        OpenTelemetry::Exporter::OTLP::Exporter.new(
          endpoint: ENV.fetch("OTEL_EXPORTER_OTLP_ENDPOINT", "https://api.honeybadger.io"),
          headers: { "X-API-Key" => ENV.fetch("HONEYBADGER_API_KEY") }
        )
      )
    )
  end
end
