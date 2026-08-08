class Api::Archidekt::DecksController < Api::ApplicationController
  def index
    @decks = Archidekt::Client.new.search(params[:q].to_s.strip)

    respond_to do |format|
      format.json { render json: { decks: @decks } }
      format.html
    end
  end
end
