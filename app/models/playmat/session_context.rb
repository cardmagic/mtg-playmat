class Playmat::SessionContext
  attr_reader :session_id

  def initialize(session_id:)
    @session_id = session_id
  end
end
