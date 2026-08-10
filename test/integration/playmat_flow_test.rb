require "test_helper"

class PlaymatFlowTest < ActionDispatch::IntegrationTest
  test "creates, joins, synchronizes, and protects hidden hands" do
    first_player = open_session
    second_player = open_session

    first_player.post "/api/spaces", params: {
      playerName: "Alice",
      spaceName: "Kitchen Table"
    }, as: :json
    assert_response_for first_player, :created
    created = first_player.response.parsed_body
    room_code = created.dig("space", "code")

    second_player.post "/api/spaces/#{room_code}/join", params: { playerName: "Bob" }, as: :json
    assert_response_for second_player, :ok
    joined = second_player.response.parsed_body
    assert_equal 2, joined.dig("space", "players").length

    stale_version = created.dig("space", "version")
    2.times do
      first_player.post "/api/spaces/#{room_code}/actions", params: {
        expectedVersion: stale_version,
        action: { type: "adjust_life", delta: -1 }
      }, as: :json
      assert_response_for first_player, :ok
    end
    assert_equal 18, current_player(first_player.response.parsed_body).fetch("life")

    first_player.get "/api/spaces/#{room_code}/state", params: {
      sinceVersion: first_player.response.parsed_body.dig("space", "version")
    }
    assert_response_for first_player, :no_content
  end

  test "accepts browser action timing measurements" do
    player = open_session
    player.get "/"

    player.post "/api/telemetry", params: {
      measurement: {
        action_type: "draw_card",
        durations: { fetch: 42.5, response_json: 1.2, render: 8.7, total: 52.4 }
      }
    }, as: :json

    assert_response_for player, :no_content
  end

  test "accepts reactive payload measurements" do
    player = open_session
    player.get "/"

    player.post "/api/telemetry", params: {
      measurement: {
        event_type: "payload_refresh",
        payload_version: 12,
        pending_actions: 1
      }
    }, as: :json

    assert_response_for player, :no_content
  end

  test "authorizes payload queries from an actor connection" do
    connection = Struct.new(:playmat_session_id).new("session-1")

    authorized = SolidObjects.configuration.authorize_query.call(
      actor_type: PlaymatRoom.actor_type,
      actor_id: "ABC123",
      authorization_context: connection
    )

    assert authorized
  end

  test "reads payload sessions from an actor connection" do
    connection = Struct.new(:playmat_session_id).new("session-1")
    context = SolidObjects.configuration.payload_authorization_context.call(connection:)

    assert_equal "session-1", context.session_id
  end

  test "authorizes queries from the resolved payload context" do
    connection = Struct.new(:playmat_session_id).new("session-1")
    context = SolidObjects.configuration.payload_authorization_context.call(connection:)

    authorized = SolidObjects.configuration.authorize_query.call(
      actor_type: PlaymatRoom.actor_type,
      actor_id: "ABC123",
      authorization_context: context
    )

    assert authorized
  end

  test "renders the playmat through a reactive Solid Objects component" do
    assert defined?(SolidObjects::ActorChannel)

    session = open_session
    session.get "/"

    assert_response_for session, :ok
    assert_includes session.response.body, "MTG Playmat"

    session.post "/api/spaces", params: { playerName: "Alice" }, as: :json
    room_code = session.response.parsed_body.dig("space", "code")
    session.get "/api/spaces/#{room_code}/observer"

    assert_response_for session, :ok
    assert_includes session.response.body, "turbo-cable-stream-source"
    assert_includes session.response.body, "SolidObjects::ActorChannel"
    assert_includes session.response.body, "<turbo-frame"
    assert_includes session.response.body, "data-playmat"
    assert_includes session.response.body, "Alice"
    assert_includes session.response.body, room_code

    source = Nokogiri::HTML5(session.response.body).at_css("turbo-cable-stream-source")
    registrations = component_tokens(source).map do |token|
      SolidObjects::ComponentRegistration.from_token(token)
    end
    player_registrations = registrations.select { |registration| registration.component_name == "player" }

    assert source["data-token"].present?
    assert_nil source["token"]
    assert_equal [ 1, 2 ], player_registrations.map(&:component_key)
    assert_equal %w[player_one player_two],
      player_registrations.map { |registration| registration.locals.fetch("player_observable") }
    assert registrations.all?(&:morph?)
    assert registrations.all? { |registration| registration.batch == "playmat" }
    assert_includes session.response.body, "solid_objects/component_refresh"
    assert_includes session.response.body, "solid_objects/component_batch_refresh"
  end

  test "refreshes batched components" do
    player = open_session
    player.get "/"
    player.post "/api/spaces", params: { playerName: "Alice" }, as: :json
    room_code = player.response.parsed_body.dig("space", "code")
    player.get "/api/spaces/#{room_code}/observer"

    source = Nokogiri::HTML5(player.response.body).at_css("turbo-cable-stream-source")
    registration = component_tokens(source).map do |token|
      SolidObjects::ComponentRegistration.from_token(token)
    end.find { |candidate| candidate.component_name == "player" }

    player.get "/solid_objects/components/batch", params: {
      instance_id: registration.instance_id,
      revision: registration.revision,
      tokens: [ registration.token ]
    }

    assert_equal 200, player.response.status, player.response.body
    assert_equal 1, player.response.parsed_body.fetch("frames").length
  end

  test "refreshes a personalized component and rejects a non-player" do
    player = open_session
    player.get "/"
    player.post "/api/spaces", params: { playerName: "Alice" }, as: :json
    room_code = player.response.parsed_body.dig("space", "code")
    player.get "/api/spaces/#{room_code}/observer"

    document = Nokogiri::HTML5(player.response.body)
    source = document.at_css("turbo-cable-stream-source")
    token = component_tokens(source).find do |candidate|
      registration = SolidObjects::ComponentRegistration.from_token(candidate)
      registration.component_name == "player" && registration.component_key == 1
    end
    registration = SolidObjects::ComponentRegistration.from_token(token)
    frame = document.at_xpath("//*[@id='#{registration.dom_id}']")
    instance_id, revision = frame["data-solid-objects-revision"].split(":")

    player.post "/api/spaces/#{room_code}/actions", params: {
      action: { type: "adjust_life", delta: -1 }
    }, as: :json
    player.get "/solid_objects/components", params: {
      token:,
      instance_id:,
      revision:
    }

    assert_response_for player, :ok
    refreshed = Nokogiri::HTML5(player.response.body)
    assert_equal "19", refreshed.at_css(".life-value").text
    assert_equal "private, no-store", player.response.headers.fetch("Cache-Control")

    outsider = open_session
    outsider.get "/"
    outsider.get "/solid_objects/components", params: {
      token:,
      instance_id:,
      revision:
    }
    assert_response_for outsider, :forbidden
  end

  test "creates and joins through server-rendered forms" do
    creator = open_session
    creator.get "/"
    creator.post "/api/spaces", params: {
      playerName: "Alice",
      spaceName: "Kitchen Table"
    }

    assert_response_for creator, :see_other
    room_path = URI.parse(creator.response.location).path
    room_code = room_path.split("/").last
    creator.follow_redirect!
    assert_response_for creator, :ok
    assert_includes creator.response.body, "data-playmat"
    assert_includes creator.response.body, "Kitchen Table"
    assert_includes creator.response.body, "solid_objects/state_payload"

    player = open_session
    player.get "/"
    player.post "/api/spaces/join", params: {
      playerName: "Bob",
      spaceCode: room_code
    }

    assert_response_for player, :see_other
    player.follow_redirect!
    assert_response_for player, :ok
    assert_includes player.response.body, "Bob"

    player.post "/api/spaces/#{room_code}/actions", params: {
      action: { type: "adjust_life", delta: -1 }
    }
    assert_response_for player, :no_content
  end

  test "loads a deck through a server-rendered form" do
    player = open_session
    player.post "/api/spaces", params: { playerName: "Alice" }, as: :json
    room_code = player.response.parsed_body.dig("space", "code")
    client_class = Class.new do
      def deck(_deck_id)
        {
          name: "Green Machine",
          cards: [
            {
              "instance_id" => "forest-1",
              "name" => "Forest",
              "scryfall_id" => "forest",
              "image_url" => "https://example.com/forest.jpg",
              "tapped" => false,
              "is_mana_source" => true
            }
          ]
        }
      end
    end

    stub_const(Archidekt, :Client, client_class) do
      player.post "/api/spaces/#{room_code}/deck", params: { deckId: "123" }
    end

    assert_response_for player, :no_content
    player.get "/api/spaces/#{room_code}/state"
    assert_response_for player, :ok
    assert_equal "Green Machine", current_player(player.response.parsed_body).fetch("deckName")
    assert_equal 1, current_player(player.response.parsed_body).fetch("library").length
  end

  test "returns the loaded deck immediately for JSON requests" do
    player = open_session
    player.post "/api/spaces", params: { playerName: "Alice" }, as: :json
    room_code = player.response.parsed_body.dig("space", "code")
    client_class = Class.new do
      def deck(_deck_id)
        { name: "Green Machine", cards: [] }
      end
    end

    stub_const(Archidekt, :Client, client_class) do
      player.post "/api/spaces/#{room_code}/deck", params: { deckId: "123" }, as: :json
    end

    assert_response_for player, :ok
    assert_equal "Green Machine", current_player(player.response.parsed_body).fetch("deckName")
  end

  test "rejects malformed actions and a third player" do
    first_player = open_session
    second_player = open_session
    third_player = open_session
    first_player.post "/api/spaces", params: { playerName: "Alice" }, as: :json
    room_code = first_player.response.parsed_body.dig("space", "code")
    second_player.post "/api/spaces/#{room_code}/join", params: { playerName: "Bob" }, as: :json
    third_player.post "/api/spaces/#{room_code}/join", params: { playerName: "Carol" }, as: :json

    assert_response_for third_player, :conflict

    first_player.post "/api/spaces/#{room_code}/actions", params: {
      action: { type: "move_battlefield_card", instanceId: "missing" }
    }, as: :json

    assert_response_for first_player, :bad_request
  end

  private

  def component_tokens(source)
    JSON.parse(source["data-components"])
  end

  def assert_response_for(session, status)
    assert_equal Rack::Utils::SYMBOL_TO_STATUS_CODE.fetch(status), session.response.status
  end

  def current_player(payload)
    payload.dig("space", "players").find do |player|
      player.fetch("id") == payload.fetch("currentPlayerId")
    end
  end
end
