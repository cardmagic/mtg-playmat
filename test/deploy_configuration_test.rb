require "test_helper"

class DeployConfigurationTest < ActiveSupport::TestCase
  test "production runs one container" do
    assert_equal [ "web" ], deploy_configuration["servers"].keys
  end

  test "the web container runs the solid objects runtime" do
    assert deploy_configuration.dig("env", "clear", "SOLID_OBJECTS_IN_PUMA")
  end

  private
    def deploy_configuration
      @deploy_configuration ||= YAML.load(rendered_deploy_file, aliases: true)
    end

    def rendered_deploy_file
      with_kamal_environment do
        ERB.new(Rails.root.join("config/deploy.yml").read).result
      end
    end

    def with_kamal_environment
      original = ENV.to_h.slice("KAMAL_SERVER_HOST", "KAMAL_PROXY_HOST")
      ENV["KAMAL_SERVER_HOST"] = "server.example"
      ENV["KAMAL_PROXY_HOST"] = "playmat.example"
      yield
    ensure
      ENV["KAMAL_SERVER_HOST"] = original["KAMAL_SERVER_HOST"]
      ENV["KAMAL_PROXY_HOST"] = original["KAMAL_PROXY_HOST"]
    end
end
