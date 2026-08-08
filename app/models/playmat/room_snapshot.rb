class Playmat::RoomSnapshot
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

  private

  def current_player
    @current_player ||= room.fetch("players").find do |player|
      player["session_id"] == session_id
    end
  end

  def public_room
    room.except("players").merge(
      "players" => room.fetch("players").map { |player| public_player(player) }
    )
  end

  def public_player(player)
    public_state = player.except("session_id")
    return public_state if player["session_id"] == session_id

    public_state.merge(
      "hand" => player.fetch("hand").each_index.map { |index| hidden_card(player, index) }
    )
  end

  def hidden_card(player, index)
    {
      "instance_id" => "hidden-#{player.fetch("id")}-#{index}",
      "name" => "Hidden card",
      "scryfall_id" => "hidden",
      "image_url" => "",
      "tapped" => false,
      "is_mana_source" => false,
      "is_hidden" => true
    }
  end
end
