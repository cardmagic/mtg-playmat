class Archidekt::DeckId
  def self.extract(value)
    normalized = value.to_s.strip
    return normalized if normalized.match?(/\A\d+\z/)

    normalized[%r{/decks/(\d+)}i, 1]
  end
end
