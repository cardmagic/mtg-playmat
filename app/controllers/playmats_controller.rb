class PlaymatsController < ApplicationController
  def show
    room_code = Playmat::RoomCode.normalize(params[:space_code])
    return if room_code.blank?

    authorization = playmat_authorization(room_code)
    room_reference = PlaymatRoom.ref(room_code)
    room = room_reference.snapshot(authorization_context: authorization).room
    snapshot = Playmat::RoomSnapshot.new(room, session_id: playmat_session_id) if room
    return redirect_to(root_path(join: room_code)) unless snapshot&.player?

    @authorization = authorization
    @room = room
    @room_reference = room_reference
  end
end
