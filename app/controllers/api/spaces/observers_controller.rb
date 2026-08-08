class Api::Spaces::ObserversController < Api::ApplicationController
  include RoomScoped

  def show
    snapshot = room_snapshot
    return head :not_found unless snapshot&.player?

    @authorization = room_authorization
    @room = snapshot.room
    @room_reference = room_reference
    render layout: false
  end
end
