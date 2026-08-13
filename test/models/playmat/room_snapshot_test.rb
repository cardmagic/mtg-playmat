require "test_helper"

class Playmat::RoomSnapshotTest < ActiveSupport::TestCase
  test "hides the other player hand and all session identifiers" do
    first_player = player("player-1", "session-1", hand: [ card("visible") ])
    second_player = player("player-2", "session-2", hand: [ card("secret") ])
    room = {
      "id" => "room-1",
      "code" => "ABC123",
      "name" => "Kitchen Table",
      "version" => 2,
      "players" => [ first_player, second_player ],
      "created_at" => "2026-01-01T00:00:00.000Z",
      "updated_at" => "2026-01-01T00:00:00.000Z"
    }

    payload = Playmat::RoomSnapshot.new(room, session_id: "session-1").payload
    current_player, other_player = payload.fetch(:space).fetch("players")

    assert_equal "player-1", payload.fetch(:currentPlayerId)
    assert_equal "Test Card", current_player.dig("hand", 0, "name")
    assert_equal "Hidden card", other_player.dig("hand", 0, "name")
    assert_equal true, other_player.dig("hand", 0, "isHidden")
    refute_includes payload.to_json, "session-1"
    refute_includes payload.to_json, "session-2"
  end

  test "hides the other player library but keeps its size" do
    first_player = player("player-1", "session-1", hand: [], library: [ card("mine") ])
    second_player = player("player-2", "session-2", hand: [], library: [ card("theirs"), card("also") ])
    room = room_with(first_player, second_player)

    payload = Playmat::RoomSnapshot.new(room, session_id: "session-1").payload
    current_player, other_player = payload.fetch(:space).fetch("players")

    assert_equal "mine", current_player.dig("library", 0, "instanceId")
    assert_equal 2, other_player.fetch("library").length
    assert_equal [ "Hidden card", "Hidden card" ], other_player.fetch("library").map { |entry| entry.fetch("name") }
    refute_includes payload.to_json, "theirs"
  end

  test "hides every hand and library from a session with no seat" do
    room = room_with(
      player("player-1", "session-1", hand: [ card("mine") ], library: [ card("library-card") ]),
      player("player-2", "session-2", hand: [ card("theirs") ], library: [])
    )

    payload = Playmat::RoomSnapshot.new(room, session_id: "session-9").payload

    assert_nil payload.fetch(:currentPlayerId)
    refute_includes payload.to_json, "mine"
    refute_includes payload.to_json, "theirs"
    refute_includes payload.to_json, "library-card"
  end

  private

  def room_with(*players)
    {
      "id" => "room-1",
      "code" => "ABC123",
      "name" => "Kitchen Table",
      "version" => 2,
      "players" => players,
      "created_at" => "2026-01-01T00:00:00.000Z",
      "updated_at" => "2026-01-01T00:00:00.000Z"
    }
  end

  def player(id, session_id, hand:, library: [])
    Playmat::Player.build(name: id, session_id:, seat: 1)
      .merge("id" => id, "hand" => hand, "library" => library)
  end

  def card(instance_id)
    {
      "instance_id" => instance_id,
      "name" => "Test Card",
      "scryfall_id" => "card",
      "image_url" => "https://example.com/card.jpg",
      "tapped" => false,
      "is_mana_source" => false
    }
  end
end
