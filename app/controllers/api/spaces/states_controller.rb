class Api::Spaces::StatesController < Api::ApplicationController
  include RoomScoped

  def show
    snapshot = room_snapshot
    return render json: { error: "Space not found" }, status: :not_found unless snapshot
    return head :no_content if unchanged?(snapshot)

    render json: snapshot.payload
  end

  private

  def unchanged?(snapshot)
    since_version = Integer(params[:sinceVersion], exception: false)
    since_version && since_version >= snapshot.payload.fetch(:space).fetch("version")
  end
end
