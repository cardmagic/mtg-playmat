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

  private

  def player(id, session_id, hand:)
    Playmat::Player.build(name: id, session_id:, seat: 1).merge("id" => id, "hand" => hand)
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
