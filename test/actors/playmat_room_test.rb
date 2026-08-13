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
    assert_equal %i[
      version
      life_totals
      player_one
      player_two
      player_one_controls
      player_two_controls
      player_one_library_search
      player_two_library_search
    ], PlaymatRoom.definition.observables.keys

    message = SolidObjects::Message.order(:id).last
    broadcasts = SolidObjects::Broadcast.where(message:).pluck(:observable_name)
    assert_equal %w[life_totals player_one version], broadcasts.sort
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
end
