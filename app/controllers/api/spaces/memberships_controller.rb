class Api::Spaces::MembershipsController < Api::ApplicationController
  include RoomScoped

  def create
    result = room_reference.sync(authorization_context: room_authorization).join(
      player_name: params[:playerName],
      session_id: playmat_session_id
    )

    case result
    when "joined"
      respond_to do |format|
        format.json { render_room }
        format.html { redirect_to playmat_path(room_reference.actor_id), status: :see_other }
      end
    when "full"
      render json: { error: "This space already has two players" }, status: :conflict
    else
      render json: { error: "Space not found" }, status: :not_found
    end
  end
end
