require "test_helper"

class PlaymatRoomTest < ActiveSupport::TestCase
  test "serializes room mutations and publishes granular observables" do
    room = PlaymatRoom.ref("ACTOR1")
    authorization = authorization_for("ACTOR1", "session-1")

    assert_equal "created", room.sync(authorization_context: authorization).create_room(
      code: "ACTOR1",
      room_name: "Kitchen Table",
      player_name: "Alice",
      session_id: "session-1"
    )
    assert_equal "applied", room.sync(authorization_context: authorization).apply_action(
      action: { type: "adjust_life", delta: -1 },
      session_id: "session-1"
    )
    assert_equal "applied", room.sync(authorization_context: authorization).apply_action(
      action: { type: "adjust_life", delta: -1 },
      session_id: "session-1"
    )

    snapshot = room.snapshot(authorization_context: authorization)

    assert_equal 18, snapshot.room.dig("players", 0, "life")
    assert_equal 3, snapshot.room.fetch("version")
    assert_equal %i[version life_totals player_one player_two],
      PlaymatRoom.definition.observables.keys

    message = SolidObjects::Message.order(:id).last
    broadcasts = SolidObjects::Broadcast.where(message:).pluck(:observable_name)
    assert_equal %w[life_totals player_one version], broadcasts.sort
  end

  test "never publishes card identity or a session identifier in a broadcast" do
    room = PlaymatRoom.ref("ACTOR3")
    authorization = authorization_for("ACTOR3", "session-1")

    room.sync(authorization_context: authorization).create_room(
      code: "ACTOR3",
      room_name: "Kitchen Table",
      player_name: "Alice",
      session_id: "session-1"
    )
    room.sync(authorization_context: authorization).load_deck(
      deck_name: "Green Machine",
      cards: [ deck_card("forest-1", "Forest"), deck_card("bear-1", "Grizzly Bears") ],
      session_id: "session-1"
    )
    room.sync(authorization_context: authorization).apply_action(
      action: { type: "draw_card", count: 1 },
      session_id: "session-1"
    )

    published = SolidObjects::Broadcast.pluck(:value).to_json

    refute_includes published, "session-1"
    refute_includes published, "Grizzly Bears"
    refute_includes published, "forest-1"
    refute_includes published, "Green Machine"
  end

  test "invalidates only the seat that changed" do
    room = PlaymatRoom.ref("ACTOR4")
    first_authorization = authorization_for("ACTOR4", "session-1")
    second_authorization = authorization_for("ACTOR4", "session-2")

    room.sync(authorization_context: first_authorization).create_room(
      code: "ACTOR4",
      room_name: "Kitchen Table",
      player_name: "Alice",
      session_id: "session-1"
    )
    room.sync(authorization_context: second_authorization).join(
      player_name: "Bob",
      session_id: "session-2"
    )
    room.sync(authorization_context: second_authorization).apply_action(
      action: { type: "adjust_life", delta: -1 },
      session_id: "session-2"
    )

    message = SolidObjects::Message.order(:id).last
    broadcasts = SolidObjects::Broadcast.where(message:).pluck(:observable_name)

    assert_equal %w[life_totals player_two version], broadcasts.sort
  end

  test "stores an empty value for an invalidation only observable" do
    room = PlaymatRoom.ref("ACTOR5")
    authorization = authorization_for("ACTOR5", "session-1")

    room.sync(authorization_context: authorization).create_room(
      code: "ACTOR5",
      room_name: "Kitchen Table",
      player_name: "Alice",
      session_id: "session-1"
    )
    room.sync(authorization_context: authorization).load_deck(
      deck_name: "Green Machine",
      cards: [ deck_card("forest-1", "Forest") ],
      session_id: "session-1"
    )

    seat_broadcast = SolidObjects::Broadcast.where(observable_name: "player_one").order(:id).last
    life_broadcast = SolidObjects::Broadcast.where(observable_name: "life_totals").order(:id).last

    refute seat_broadcast.broadcasts_value?
    assert_equal({}, seat_broadcast.value)
    assert life_broadcast.broadcasts_value?
    assert_equal({ "1" => 20 }, life_broadcast.value)
  end

  test "limits a room to two sessions" do
    room = PlaymatRoom.ref("ACTOR2")
    first_authorization = authorization_for("ACTOR2", "session-1")
    second_authorization = authorization_for("ACTOR2", "session-2")
    third_authorization = authorization_for("ACTOR2", "session-3")

    room.sync(authorization_context: first_authorization).create_room(
      code: "ACTOR2",
      room_name: "Kitchen Table",
      player_name: "Alice",
      session_id: "session-1"
    )

    assert_equal "joined", room.sync(authorization_context: second_authorization).join(
      player_name: "Bob",
      session_id: "session-2"
    )
    assert_equal "full", room.sync(authorization_context: third_authorization).join(
      player_name: "Carol",
      session_id: "session-3"
    )
  end

  private

  def authorization_for(room_code, session_id)
    Playmat::Authorization.new(room_code:, session_id:)
  end

  def deck_card(instance_id, name)
    {
      "instance_id" => instance_id,
      "name" => name,
      "scryfall_id" => instance_id,
      "image_url" => "https://example.com/#{instance_id}.jpg",
      "tapped" => false,
      "is_mana_source" => false
    }
  end
end
