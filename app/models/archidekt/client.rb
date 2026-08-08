require "net/http"

class Archidekt::Client
  BASE_URL = "https://archidekt.com"
  MAXIMUM_SEARCH_PAGES = 4
  MAXIMUM_SEARCH_RESULTS = 120

  def search(query)
    return [] if query.strip.length < 2

    decks = fetch_search_pages(query)
    decks.first(MAXIMUM_SEARCH_RESULTS).map { |deck| search_result(deck) }
  end

  def deck(deck_id)
    payload = get_json("#{BASE_URL}/api/decks/#{deck_id}/")
    {
      name: string_value(payload["name"], fallback: "Deck"),
      cards: deck_cards(payload).shuffle
    }
  end

  private

  def fetch_search_pages(query)
    decks = []
    next_page_url = "#{BASE_URL}/api/decks/v3/?name=#{ERB::Util.url_encode(query)}&page=1"

    MAXIMUM_SEARCH_PAGES.times do
      break if next_page_url.blank?

      payload = get_json(next_page_url)
      decks.concat(Array(payload["results"]))
      break if decks.length >= MAXIMUM_SEARCH_RESULTS

      next_page_url = trusted_next_page(payload["next"])
    end
    decks
  end

  def get_json(url)
    uri = URI.parse(url)
    raise Archidekt::Error, "Untrusted Archidekt URL" unless trusted_uri?(uri)

    request = Net::HTTP::Get.new(uri)
    response = Net::HTTP.start(
      uri.host,
      uri.port,
      use_ssl: true,
      open_timeout: 5,
      read_timeout: 15
    ) { |http| http.request(request) }
    raise Archidekt::Error, "Archidekt returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue JSON::ParserError, SocketError, SystemCallError, Timeout::Error, URI::InvalidURIError => error
    raise Archidekt::Error, error.message
  end

  def trusted_next_page(value)
    return if value.blank?

    uri = URI.parse(value)
    trusted_uri?(uri) ? uri.to_s : nil
  rescue URI::InvalidURIError
    nil
  end

  def trusted_uri?(uri)
    uri.is_a?(URI::HTTPS) && uri.host == "archidekt.com"
  end

  def search_result(deck)
    {
      id: deck["id"].to_i,
      name: string_value(deck["name"], fallback: "Untitled Deck"),
      ownerName: string_value(deck.dig("owner", "username"), fallback: "Unknown"),
      size: deck["size"].to_i,
      updatedAt: string_value(deck["updatedAt"], fallback: "").first(10),
      featuredUrl: string_value(deck["featured"], fallback: "").presence,
      colorBands: color_bands(deck["colors"])
    }
  end

  def color_bands(colors)
    return [] unless colors.is_a?(Hash)

    %w[W U B R G].filter_map do |symbol|
      weight = colors[symbol]
      next unless weight.is_a?(Numeric) && weight.positive?

      { color: symbol, weight: [ weight.round, 1 ].max }
    end
  end

  def deck_cards(payload)
    category_inclusion = category_inclusion(payload["categories"])
    Array(payload["cards"]).flat_map do |card|
      next [] unless include_card?(card, category_inclusion)

      expand_card(card)
    end
  end

  def category_inclusion(categories)
    Array(categories).to_h do |category|
      [
        string_value(category["name"], fallback: ""),
        category.fetch("includedInDeck", true)
      ]
    end
  end

  def include_card?(card, category_inclusion)
    categories = Array(card["categories"])
    return false if categories.include?("Sideboard")

    primary_category = categories.first
    return true if primary_category.blank?
    return true unless category_inclusion.key?(primary_category)

    category_inclusion.fetch(primary_category)
  end

  def expand_card(card)
    quantity = card.fetch("quantity", 1).to_i.clamp(0, 20)
    scryfall_id = string_value(card.dig("card", "uid"), fallback: "")
    return [] if scryfall_id.blank?

    name = string_value(card.dig("card", "displayName"), fallback: "")
    name = string_value(card.dig("card", "oracleCard", "name"), fallback: "Unknown Card") if name.blank?

    Array.new(quantity) do
      {
        "instance_id" => SecureRandom.uuid,
        "name" => name,
        "scryfall_id" => scryfall_id,
        "image_url" => scryfall_image_url(scryfall_id),
        "tapped" => false,
        "is_mana_source" => mana_source?(card)
      }
    end
  end

  def mana_source?(card)
    type_line = string_value(card.dig("card", "oracleCard", "typeLine"), fallback: "").downcase
    return true if type_line.include?("land")

    oracle_text = string_value(card.dig("card", "oracleCard", "text"), fallback: "")
    oracle_text.include?("Add {")
  end

  def scryfall_image_url(scryfall_id)
    "https://cards.scryfall.io/normal/front/#{scryfall_id[0]}/#{scryfall_id[1]}/#{scryfall_id}.jpg"
  end

  def string_value(value, fallback:)
    value.is_a?(String) && value.present? ? value : fallback
  end
end
