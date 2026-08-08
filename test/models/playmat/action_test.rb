require "test_helper"

class Playmat::ActionTest < ActiveSupport::TestCase
  test "parses camel case action attributes" do
    action = Playmat::Action.parse(
      type: "move_battlefield_card",
      instanceId: "card-1",
      x: 12.5,
      y: 30
    )

    assert_equal "move_battlefield_card", action.type
    assert_equal "card-1", action["instance_id"]
    assert_equal 12.5, action["x"]
  end

  test "normalizes library search aliases" do
    assert_equal "open_deck_search", Playmat::Action.parse(type: "open_library_search").type
    assert_equal "close_deck_search", Playmat::Action.parse(type: "close_library_search").type
  end

  test "normalizes numeric form fields before validation" do
    action = Playmat::Action.parse(type: "move_battlefield_card", instanceId: "card-1", x: "12.5", y: "24")

    assert_equal 12.5, action["x"]
    assert_equal 24.0, action["y"]
  end

  test "rejects malformed actions" do
    assert_nil Playmat::Action.parse(type: "move_battlefield_card", instanceId: "card-1")
    assert_nil Playmat::Action.parse(type: "move_card_zone", instanceId: "card-1", from: "void", to: "hand")
    assert_nil Playmat::Action.parse(type: "unknown")
  end
end
