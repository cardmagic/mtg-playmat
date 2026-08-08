class Playmat::Player
  DECK_CARD_KEYS = %w[instance_id name scryfall_id image_url tapped is_mana_source].freeze

  def self.build(name:, session_id:, seat:)
    {
      "id" => SecureRandom.uuid,
      "session_id" => session_id,
      "name" => name,
      "seat" => seat,
      "life" => 20,
      "deck_name" => nil,
      "library" => [],
      "hand" => [],
      "battlefield" => [],
      "graveyard" => [],
      "exile" => [],
      "is_searching_deck" => false
    }
  end

  def initialize(state)
    @state = state.deep_dup
  end

  def apply(action)
    case action.type
    when "draw_card"
      draw_cards(action["count"]&.to_i || 1)
    when "shuffle_library"
      replace("library" => state.fetch("library").shuffle)
    when "untap_all"
      untap_all
    when "open_deck_search"
      replace("is_searching_deck" => true)
    when "close_deck_search"
      replace("is_searching_deck" => false)
    when "move_library_card_to_hand"
      move_library_card_to_hand(action["instance_id"])
    when "play_from_hand"
      play_from_hand(action["instance_id"])
    when "toggle_tap"
      toggle_tap(action["instance_id"])
    when "move_battlefield_card"
      move_battlefield_card(action["instance_id"], x: action["x"], y: action["y"])
    when "move_card_zone"
      move_card_between_zones(action)
    when "move_to_deck"
      move_to_deck(action)
    when "adjust_life"
      replace("life" => clamp(state.fetch("life") + action["delta"].to_i, within: 0..999))
    when "reset_life"
      replace("life" => 20)
    when "set_life"
      replace("life" => clamp(action["value"].to_i, within: 0..999))
    when "add_counter"
      add_counter(action)
    when "move_counter"
      move_counter(action)
    when "update_counter_value"
      update_counter_value(action)
    else
      state
    end
  end

  private

  attr_reader :state

  def draw_cards(requested_count)
    return state if state.fetch("library").empty?

    count = clamp(requested_count, within: 1..12)
    cards = state.fetch("library").first(count)
    replace(
      "library" => state.fetch("library").drop(count),
      "hand" => state.fetch("hand") + cards
    )
  end

  def move_library_card_to_hand(instance_id)
    card = state.fetch("library").find { |candidate| candidate["instance_id"] == instance_id }
    return state unless card

    replace(
      "library" => without_card(state.fetch("library"), instance_id),
      "hand" => state.fetch("hand") + [ card ]
    )
  end

  def play_from_hand(instance_id)
    card = state.fetch("hand").find { |candidate| candidate["instance_id"] == instance_id }
    return state unless card

    replace(
      "hand" => without_card(state.fetch("hand"), instance_id),
      "battlefield" => state.fetch("battlefield") + [ battlefield_card(card, x: 240, y: 140) ]
    )
  end

  def toggle_tap(instance_id)
    battlefield = state.fetch("battlefield").map do |card|
      next card unless card["instance_id"] == instance_id

      card.merge("tapped" => !card.fetch("tapped"))
    end
    replace("battlefield" => battlefield)
  end

  def untap_all
    battlefield = state.fetch("battlefield").map { |card| card.merge("tapped" => false) }
    replace("battlefield" => battlefield)
  end

  def move_battlefield_card(instance_id, x:, y:)
    battlefield = state.fetch("battlefield").map do |card|
      next card unless card["instance_id"] == instance_id

      card.merge(
        "x" => clamp(x, within: 0..1200),
        "y" => clamp(y, within: 0..700)
      )
    end
    replace("battlefield" => battlefield)
  end

  def move_card_between_zones(action)
    return state if action["from"] == action["to"]

    card, player_without_card = remove_card(
      state,
      zone: action["from"],
      instance_id: action["instance_id"]
    )
    return state unless card

    if action["to"] == "battlefield"
      battlefield = player_without_card.fetch("battlefield") + [
        battlefield_card(
          deck_card(card),
          x: clamp(action["x"] || 40, within: 0..1200),
          y: clamp(action["y"] || 40, within: 0..700)
        )
      ]
      return player_without_card.merge("battlefield" => battlefield)
    end

    destination = player_without_card.fetch(action["to"]) + [ deck_card(card) ]
    player_without_card.merge(action["to"] => destination)
  end

  def move_to_deck(action)
    card, player_without_card = remove_card(
      state,
      zone: action["from"],
      instance_id: action["instance_id"]
    )
    return state unless card

    card = deck_card(card)
    library = case action["position"]
    when "top"
      [ card ] + player_without_card.fetch("library")
    when "shuffle"
      (player_without_card.fetch("library") + [ card ]).shuffle
    else
      player_without_card.fetch("library") + [ card ]
    end
    player_without_card.merge("library" => library)
  end

  def add_counter(action)
    battlefield = state.fetch("battlefield").map do |card|
      next card unless card["instance_id"] == action["instance_id"]

      counter = {
        "id" => SecureRandom.uuid,
        "label" => (action["label"] || "+1/+1").first(8),
        "value" => 0,
        "x" => clamp(action["x"], within: 0..96),
        "y" => clamp(action["y"], within: 0..136)
      }
      card.merge("counters" => card.fetch("counters") + [ counter ])
    end
    replace("battlefield" => battlefield)
  end

  def move_counter(action)
    battlefield = state.fetch("battlefield").map do |card|
      next card unless card["instance_id"] == action["instance_id"]

      counters = card.fetch("counters").map do |counter|
        next counter unless counter["id"] == action["counter_id"]

        counter.merge(
          "x" => clamp(action["x"], within: 0..96),
          "y" => clamp(action["y"], within: 0..136)
        )
      end
      card.merge("counters" => counters)
    end
    replace("battlefield" => battlefield)
  end

  def update_counter_value(action)
    battlefield = state.fetch("battlefield").map do |card|
      next card unless card["instance_id"] == action["instance_id"]

      counters = card.fetch("counters").filter_map do |counter|
        next counter unless counter["id"] == action["counter_id"]

        value = clamp(counter.fetch("value") + action["delta"].to_i, within: -999..999)
        counter.merge("value" => value) unless value.zero?
      end
      card.merge("counters" => counters)
    end
    replace("battlefield" => battlefield)
  end

  def remove_card(player, zone:, instance_id:)
    cards = player.fetch(zone)
    card = cards.find { |candidate| candidate["instance_id"] == instance_id }
    return [ nil, player ] unless card

    [ card, player.merge(zone => without_card(cards, instance_id)) ]
  end

  def without_card(cards, instance_id)
    cards.reject { |card| card["instance_id"] == instance_id }
  end

  def battlefield_card(card, x:, y:)
    card.merge("x" => x, "y" => y, "counters" => [])
  end

  def deck_card(card)
    card.slice(*DECK_CARD_KEYS)
  end

  def clamp(value, within:)
    value.clamp(within.begin, within.end)
  end

  def replace(attributes)
    state.merge(attributes)
  end
end
