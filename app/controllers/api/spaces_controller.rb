class Api::SpacesController < Api::ApplicationController
  MAXIMUM_CODE_ATTEMPTS = 8

  def create
    MAXIMUM_CODE_ATTEMPTS.times do
      room_code = Playmat::RoomCode.generate
      room_reference = PlaymatRoom.ref(room_code)
      authorization = playmat_authorization(room_code)
      result = room_reference.sync(authorization_context: authorization).create_room(
        code: room_code,
        room_name: params[:spaceName],
        player_name: params[:playerName],
        session_id: playmat_session_id
      )
      next if result == "exists"

      room = room_reference.snapshot(authorization_context: authorization).room
      snapshot = Playmat::RoomSnapshot.new(room, session_id: playmat_session_id)
      return respond_to do |format|
        format.json { render json: snapshot.payload, status: :created }
        format.html { redirect_to playmat_path(room_code), status: :see_other }
      end
    end

    render json: { error: "Could not create a unique space code" }, status: :internal_server_error
  end
end
