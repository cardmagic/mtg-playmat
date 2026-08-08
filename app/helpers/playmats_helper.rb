module PlaymatsHelper
  def playmat_action_path(room_code)
    application_routes.api_space_actions_path(room_code)
  end

  def playmat_deck_path(room_code)
    application_routes.api_space_deck_path(room_code)
  end

  def playmat_deck_search_path(parameters = {})
    application_routes.api_archidekt_decks_path(parameters)
  end

  def playmat_share_url(room_code)
    "#{request.base_url}#{application_routes.root_path(join: room_code)}"
  end

  def battlefield_canvas_style(cards)
    return "width:1px;height:1px;" if cards.empty?

    maximum_right_edge = cards.map do |card|
      card.fetch("x") + (card.fetch("tapped") ? 162 : 116)
    end.max
    maximum_bottom_edge = cards.map do |card|
      card.fetch("y") + (card.fetch("tapped") ? 116 : 162)
    end.max

    "width:#{(maximum_right_edge + 140).ceil}px;height:#{(maximum_bottom_edge + 160).ceil}px;"
  end

  private

  def application_routes
    Rails.application.routes.url_helpers
  end
end
