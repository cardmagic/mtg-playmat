class Api::Spaces::DecksController < Api::ApplicationController
  include RoomScoped

  def create
    deck_id = Archidekt::DeckId.extract(params[:deckId])
    return render json: { error: "Deck ID or Archidekt deck URL is required" }, status: :bad_request unless deck_id

    snapshot = room_snapshot
    return render json: { error: "Space not found" }, status: :not_found unless snapshot
    return render json: { error: "You are not a player in this space" }, status: :forbidden unless snapshot.player?

    deck = Archidekt::Client.new.deck(deck_id)
    result = room_reference.load_deck(
      deck_name: deck.fetch(:name),
      cards: deck.fetch(:cards),
      session_id: playmat_session_id,
      authorization_context: room_authorization
    )
    return render_room if result == "loaded"

    render json: { error: "Could not load deck #{deck_id}" }, status: :bad_gateway
  end
end
