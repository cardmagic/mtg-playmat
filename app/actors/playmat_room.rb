class PlaymatRoom < SolidObjects::Actor
  actor_type "playmat_room"

  attribute :room, default: nil

  # A :value observable reaches every authorized subscriber of this actor, and
  # both seats subscribe to one stream. Only room-wide, public facts travel that
  # way.
  observable :version do
    room&.fetch("version", 0) || 0
  end

  observable :life_totals do
    room&.fetch("players", [])&.to_h do |player|
      [ player.fetch("seat").to_s, player.fetch("life") ]
    end || {}
  end

  # A seat holds a session identifier, a hand, and a library. These observables
  # drive component refreshes without ever putting that on the wire. Each
  # component then renders under the requesting session's own authorization.
  observable :player_one, broadcast: :invalidation do
    player_in_seat(1)
  end

  observable :player_two, broadcast: :invalidation do
    player_in_seat(2)
  end

  broadcast_payload :playmat_state do |actor, authorization_context|
    Playmat::RoomSnapshot.new(
      actor.room,
      session_id: authorization_context.session_id
    ).payload
  end

  def create_room(code:, room_name:, player_name:, session_id:)
    return "exists" if room

    creator = Playmat::Player.build(
      name: normalized_player_name(player_name, fallback: "Player 1"),
      session_id:,
      seat: 1
    )
    timestamp = current_timestamp
    self.room = {
      "id" => SecureRandom.uuid,
      "code" => code,
      "name" => normalized_room_name(room_name),
      "version" => 1,
      "players" => [ creator ],
      "created_at" => timestamp,
      "updated_at" => timestamp
    }
    "created"
  end

  def join(player_name:, session_id:)
    return "not_found" unless room
    return "joined" if player_for(session_id)
    return "full" if room.fetch("players").length >= 2

    seat = room.fetch("players").length + 1
    player = Playmat::Player.build(
      name: normalized_player_name(player_name, fallback: "Player #{seat}"),
      session_id:,
      seat:
    )
    commit(room.merge("players" => room.fetch("players") + [ player ]))
    "joined"
  end

  def load_deck(deck_name:, cards:, session_id:)
    return "not_found" unless room

    player = player_for(session_id)
    return "forbidden" unless player

    replacement = player.merge(
      "life" => 20,
      "deck_name" => deck_name,
      "library" => cards,
      "hand" => [],
      "battlefield" => [],
      "graveyard" => [],
      "exile" => [],
      "is_searching_deck" => false
    )
    commit(replace_player(replacement))
    "loaded"
  end

  def apply_action(action:, session_id:)
    action_type = action.is_a?(Hash) && (action["type"] || action[:type]).to_s
    tracer = OpenTelemetry.tracer_provider.tracer("mtg-playmat")

    tracer.in_span("playmat.actor_action", attributes: { "playmat.action.type" => action_type }) do |span|
      return "not_found" unless room

      player = player_for(session_id)
      return "forbidden" unless player

      parsed_action = tracer.in_span("playmat.action.parse") { Playmat::Action.parse(action) }
      return "invalid" unless parsed_action

      replacement = tracer.in_span("playmat.action.apply") { Playmat::Player.new(player).apply(parsed_action) }
      tracer.in_span("playmat.action.commit") do
        commit(replace_player(replacement))
      end
      span.set_attribute("playmat.action.result", "applied")
      "applied"
    end
  end

  private

  def player_for(session_id)
    room.fetch("players").find { |player| player["session_id"] == session_id }
  end

  def player_in_seat(seat)
    room&.fetch("players", [])&.find { |player| player["seat"] == seat }
  end

  def replace_player(replacement)
    players = room.fetch("players").map do |player|
      player["id"] == replacement["id"] ? replacement : player
    end
    room.merge("players" => players)
  end

  def commit(next_room)
    self.room = next_room.merge(
      "version" => room.fetch("version") + 1,
      "updated_at" => current_timestamp
    )
  end

  def normalized_player_name(value, fallback:)
    normalized_name(value, fallback:, maximum_length: 28)
  end

  def normalized_room_name(value)
    normalized_name(value, fallback: "Gaming Table", maximum_length: 40)
  end

  def normalized_name(value, fallback:, maximum_length:)
    return fallback unless value.is_a?(String)

    value.strip.presence&.first(maximum_length) || fallback
  end

  def current_timestamp
    Time.current.iso8601(3)
  end
end
