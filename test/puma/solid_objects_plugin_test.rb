require "test_helper"
require "puma/plugin"
require_relative "../../lib/puma/plugin/solid_objects"

class SolidObjectsPluginTest < ActiveSupport::TestCase
  class RecordingSupervisor
    attr_reader :calls

    def initialize
      @calls = []
      @lock = Thread::Mutex.new
      @gate = Thread::Queue.new
      @running = Thread::Queue.new
      @finished = false
    end

    def start
      @calls << :start
    end

    def run
      @running << :running
      @gate.pop
      @finished = true
    end

    def stop
      @lock.synchronize { @calls << :stop }
      @gate << :stopped
    end

    def finished?
      @finished
    end

    def wait_until_running
      raise "the plugin never ran the runtime" unless @running.pop(timeout: 5)
    end
  end

  class RecordingLoader
    attr_reader :calls

    def initialize
      @calls = []
    end

    def install
      calls << :install
    end
  end

  class FakeEvents
    def initialize
      @hooks = Hash.new { |hooks, name| hooks[name] = [] }
    end

    def after_booted(&block)
      @hooks[:after_booted] << block
    end

    def after_stopped(&block)
      @hooks[:after_stopped] << block
    end

    def before_restart(&block)
      @hooks[:before_restart] << block
    end

    def fire(name)
      @hooks[name].each(&:call)
    end
  end

  class FakeLogWriter
    attr_reader :messages

    def initialize
      @messages = []
    end

    def log(message)
      messages << message
    end
  end

  class FakeLauncher
    attr_reader :events, :options, :log_writer

    def initialize(workers: 0)
      @events = FakeEvents.new
      @options = { workers: }
      @log_writer = FakeLogWriter.new
    end
  end

  test "registers a puma plugin named solid_objects" do
    assert Puma::Plugins.find("solid_objects")
  end

  test "builds the real solid objects collaborators" do
    plugin = Puma::Plugins.find("solid_objects").new
    loader = plugin.send(:actor_loader)
    supervisor = plugin.send(:build_supervisor)

    assert_kind_of SolidObjects::ApplicationActorLoader, loader
    assert_kind_of SolidObjects::Supervisor, supervisor
  end

  test "runs the runtime on its own thread after puma boots" do
    with_started_plugin do |launcher, supervisor|
      assert_empty supervisor.calls

      launcher.events.fire(:after_booted)
      supervisor.wait_until_running

      assert_equal [ :start ], supervisor.calls
    end
  end

  test "loads the application actors before it runs the runtime" do
    with_started_plugin do |launcher, supervisor, loader|
      launcher.events.fire(:after_booted)
      supervisor.wait_until_running

      assert_equal [ :install ], loader.calls
    end
  end

  test "waits for the runtime to finish after puma stops" do
    with_started_plugin do |launcher, supervisor|
      launcher.events.fire(:after_booted)
      launcher.events.fire(:after_stopped)

      assert_equal [ :start, :stop ], supervisor.calls
      assert_predicate supervisor, :finished?
    end
  end

  test "waits for the runtime to finish before puma restarts" do
    with_started_plugin do |launcher, supervisor|
      launcher.events.fire(:after_booted)
      launcher.events.fire(:before_restart)

      assert_equal [ :start, :stop ], supervisor.calls
      assert_predicate supervisor, :finished?
    end
  end

  test "stops the runtime once when puma restarts and then stops" do
    with_started_plugin do |launcher, supervisor|
      launcher.events.fire(:after_booted)
      launcher.events.fire(:before_restart)
      launcher.events.fire(:after_stopped)

      assert_equal [ :start, :stop ], supervisor.calls
    end
  end

  test "stops the runtime from inside a signal trap" do
    with_started_plugin do |launcher, supervisor|
      launcher.events.fire(:after_booted)

      in_trap_context { launcher.events.fire(:after_stopped) }

      assert_equal [ :start, :stop ], supervisor.calls
      assert_predicate supervisor, :finished?
    end
  end

  test "starts the runtime before it returns from the boot hook" do
    with_started_plugin do |launcher, supervisor|
      launcher.events.fire(:after_booted)

      assert_equal [ :start ], supervisor.calls
    end
  end

  test "stops nothing when puma stops before it boots" do
    with_started_plugin do |launcher, supervisor|
      launcher.events.fire(:after_stopped)

      assert_empty supervisor.calls
    end
  end

  test "refuses to start when puma runs in cluster mode" do
    error = assert_raises(RuntimeError) do
      with_started_plugin(workers: 2) { }
    end

    assert_match(/single mode/, error.message)
  end

  private
    def in_trap_context
      outcome = Thread::Queue.new
      previous = Signal.trap("USR2") do
        begin
          yield
          outcome << nil
        rescue Exception => error # rubocop:disable Lint/RescueException
          outcome << error
        end
      end

      ::Process.kill("USR2", ::Process.pid)
      error = outcome.pop(timeout: 10)
      raise error if error
    ensure
      Signal.trap("USR2", previous) if previous
    end

    def with_started_plugin(workers: 0)
      launcher = FakeLauncher.new(workers:)
      plugin = plugin_class.new
      plugin.start(launcher)
      yield launcher, plugin.recorded_supervisor, plugin.recorded_loader
    ensure
      launcher&.events&.fire(:after_stopped)
    end

    def plugin_class
      @plugin_class ||= Class.new(Puma::Plugins.find("solid_objects")) do
        attr_reader :recorded_supervisor, :recorded_loader

        def initialize
          @recorded_supervisor = RecordingSupervisor.new
          @recorded_loader = RecordingLoader.new
        end

        private
          def actor_loader
            recorded_loader
          end

          def build_supervisor
            recorded_supervisor
          end
      end
    end
end
