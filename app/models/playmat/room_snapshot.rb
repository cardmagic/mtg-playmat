class Playmat::RoomSnapshot
  HIDDEN_ZONES = %w[hand library].freeze

  attr_reader :room, :session_id

  def initialize(room, session_id:)
    @room = room
    @session_id = session_id
  end

  def payload
    {
      space: public_room.deep_transform_keys { |key| key.camelize(:lower) },
      currentPlayerId: current_player&.fetch("id")
    }
  end

  def player?
    current_player.present?
  end

  def current_player_id
    current_player&.fetch("id")
  end

  def current_seat
    current_player&.fetch("seat")
  end

  def visible_player_in_seat(seat)
    public_room.fetch("players").find { |player| player.fetch("seat") == seat }
  end

  def public_room
    @public_room ||= room.except("players").merge(
      "players" => room.fetch("players").map { |player| public_player(player) }
    )
  end

  private

  def current_player
    @current_player ||= room.fetch("players").find do |player|
      player["session_id"] == session_id
    end
  end

  def public_player(player)
    public_state = player.except("session_id")
    return public_state if own_player?(player)

    public_state.merge(
      HIDDEN_ZONES.to_h { |zone| [ zone, hidden_zone(player, zone) ] }
    )
  end

  def own_player?(player)
    session_id.present? && player["session_id"] == session_id
  end

  def hidden_zone(player, zone)
    player.fetch(zone).each_index.map { |index| hidden_card(player, zone, index) }
  end

  def hidden_card(player, zone, index)
    {
      "instance_id" => "hidden-#{player.fetch("id")}-#{zone}-#{index}",
      "name" => "Hidden card",
      "scryfall_id" => "hidden",
      "image_url" => "",
      "tapped" => false,
      "is_mana_source" => false,
      "is_hidden" => true
    }
  end
end
