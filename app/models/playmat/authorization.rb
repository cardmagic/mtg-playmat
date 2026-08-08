class Playmat::Authorization
  attr_reader :room_code, :session_id

  def initialize(room_code:, session_id:)
    @room_code = room_code
    @session_id = session_id
  end

  def valid_for?(actor_type:, actor_id:)
    actor_type == PlaymatRoom.actor_type &&
      actor_id == room_code &&
      session_id.present?
  end

  def player_in?(room)
    room&.fetch("players", [])&.any? { |player| player["session_id"] == session_id }
  end
end
