require "puma/plugin"

Puma::Plugin.create do
  def start(launcher)
    refuse_cluster_mode(launcher)

    @launcher = launcher
    @supervisor = nil
    @runtime = nil

    launcher.events.after_booted { start_runtime }
    launcher.events.after_stopped { stop_runtime }
    launcher.events.before_restart { stop_runtime }
  end

  private
    def refuse_cluster_mode(launcher)
      workers = launcher.options[:workers].to_i
      return if workers.zero?

      raise "The Solid Objects runtime needs Puma in single mode, " \
        "but Puma is configured with #{workers} workers."
    end

    def start_runtime
      actor_loader.install
      supervisor = build_supervisor
      supervisor.start
      @supervisor = supervisor
      @runtime = Thread.new { supervisor.run }
      log "Started the Solid Objects runtime in Puma."
    end

    def stop_runtime
      supervisor = @supervisor
      runtime = @runtime
      @supervisor = nil
      @runtime = nil
      return unless supervisor

      log "Stopping the Solid Objects runtime..."
      Thread.new do
        supervisor.stop
        runtime&.join
      end.join
    end

    def actor_loader
      require "solid_objects/application_actor_loader"
      SolidObjects::ApplicationActorLoader.new
    end

    def build_supervisor
      SolidObjects::Supervisor.new
    end

    def log(message)
      @launcher.log_writer.log(message)
    end
end
