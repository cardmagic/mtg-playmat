require "test_helper"

class Playmat::PlayerTest < ActiveSupport::TestCase
  test "draws a card from the library" do
    player = player_with_cards

    updated_player = apply(player, type: "draw_card", count: 1)

    assert_empty updated_player.fetch("library")
    assert_equal 2, updated_player.fetch("hand").length
  end

  test "plays, taps, and untaps a card" do
    player = player_with_cards

    played = apply(player, type: "play_from_hand", instanceId: "hand-1")
    tapped = apply(played, type: "toggle_tap", instanceId: "hand-1")
    untapped = apply(tapped, type: "untap_all")

    assert_empty played.fetch("hand")
    assert_equal true, tapped.dig("battlefield", 0, "tapped")
    assert_equal false, untapped.dig("battlefield", 0, "tapped")
  end

  test "adjusts and resets life" do
    damaged = apply(player_with_cards, type: "adjust_life", delta: -7)
    reset = apply(damaged, type: "reset_life")

    assert_equal 13, damaged.fetch("life")
    assert_equal 20, reset.fetch("life")
  end

  test "moves cards between zones" do
    played = apply(player_with_cards, type: "play_from_hand", instanceId: "hand-1")
    discarded = apply(
      played,
      type: "move_card_zone",
      instanceId: "hand-1",
      from: "battlefield",
      to: "graveyard"
    )
    returned = apply(
      discarded,
      type: "move_card_zone",
      instanceId: "hand-1",
      from: "graveyard",
      to: "battlefield",
      x: 50,
      y: 70
    )

    assert_empty discarded.fetch("battlefield")
    assert_equal "hand-1", discarded.dig("graveyard", 0, "instance_id")
    assert_equal 50, returned.dig("battlefield", 0, "x")
    assert_equal 70, returned.dig("battlefield", 0, "y")
  end

  test "moves cards to the top and bottom of the library" do
    played = apply(player_with_cards, type: "play_from_hand", instanceId: "hand-1")
    moved_to_top = apply(
      played,
      type: "move_to_deck",
      instanceId: "hand-1",
      from: "battlefield",
      position: "top"
    )

    assert_equal "hand-1", moved_to_top.dig("library", 0, "instance_id")

    drawn = apply(moved_to_top, type: "draw_card", count: 1)
    replayed = apply(drawn, type: "play_from_hand", instanceId: "hand-1")
    moved_to_bottom = apply(
      replayed,
      type: "move_to_deck",
      instanceId: "hand-1",
      from: "battlefield",
      position: "bottom"
    )

    assert_equal "hand-1", moved_to_bottom.fetch("library").last.fetch("instance_id")
  end

  test "adds, changes, moves, and removes counters" do
    played = apply(player_with_cards, type: "play_from_hand", instanceId: "hand-1")
    added = apply(
      played,
      type: "add_counter",
      instanceId: "hand-1",
      x: 10,
      y: 20,
      label: "+1/+1"
    )
    counter_id = added.dig("battlefield", 0, "counters", 0, "id")
    incremented = apply(
      added,
      type: "update_counter_value",
      instanceId: "hand-1",
      counterId: counter_id,
      delta: 1
    )
    moved = apply(
      incremented,
      type: "move_counter",
      instanceId: "hand-1",
      counterId: counter_id,
      x: 40,
      y: 50
    )
    removed = apply(
      moved,
      type: "update_counter_value",
      instanceId: "hand-1",
      counterId: counter_id,
      delta: -1
    )

    assert_equal 1, incremented.dig("battlefield", 0, "counters", 0, "value")
    assert_equal 40, moved.dig("battlefield", 0, "counters", 0, "x")
    assert_empty removed.dig("battlefield", 0, "counters")
  end

  private

  def apply(player, attributes)
    Playmat::Player.new(player).apply(Playmat::Action.parse(attributes))
  end

  def player_with_cards
    Playmat::Player.build(name: "Player One", session_id: "session-1", seat: 1).merge(
      "deck_name" => "Demo Deck",
      "library" => [ card("library-1") ],
      "hand" => [ card("hand-1") ]
    )
  end

  def card(instance_id)
    {
      "instance_id" => instance_id,
      "name" => "Test Card",
      "scryfall_id" => "92b0be6d-9183-4938-b7a1-ae7f04ba78a0",
      "image_url" => "https://cards.scryfall.io/normal/front/9/2/card.jpg",
      "tapped" => false,
      "is_mana_source" => false
    }
  end
end
