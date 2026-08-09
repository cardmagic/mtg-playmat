module RoomScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_room
  end

  private

  attr_reader :room_authorization, :room_reference

  def set_room
    room_code = Playmat::RoomCode.normalize(params[:space_code] || params[:spaceCode])
    return render json: { error: "Space not found" }, status: :not_found if room_code.blank?

    @room_reference = PlaymatRoom.ref(room_code)
    @room_authorization = playmat_authorization(room_code)
  end

  def room_state
    room_reference.snapshot(authorization_context: room_authorization).room
  end

  def room_snapshot
    room = room_state
    Playmat::RoomSnapshot.new(room, session_id: playmat_session_id) if room
  end

  def render_room(status: :ok)
    return head :no_content if request.format.html? || request.format.turbo_stream?

    snapshot = room_snapshot
    return render json: { error: "Space not found" }, status: :not_found unless snapshot

    respond_to do |format|
      format.json { render json: snapshot.payload, status: }
    end
  end
end
