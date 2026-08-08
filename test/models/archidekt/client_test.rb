require "test_helper"

class Archidekt::ClientTest < ActiveSupport::TestCase
  class StubClient < Archidekt::Client
    def initialize(payload)
      @payload = payload
    end

    private

    attr_reader :payload

    def get_json(_url)
      payload
    end
  end

  test "maps searchable deck metadata" do
    client = StubClient.new(
      "results" => [
        {
          "id" => 42,
          "name" => "Old School",
          "owner" => { "username" => "wizard" },
          "size" => 60,
          "updatedAt" => "2026-08-06T10:00:00Z",
          "featured" => "https://example.com/deck.jpg",
          "colors" => { "W" => 2, "U" => 1 }
        }
      ],
      "next" => nil
    )

    deck = client.search("old school").first

    assert_equal 42, deck.fetch(:id)
    assert_equal "wizard", deck.fetch(:ownerName)
    assert_equal "2026-08-06", deck.fetch(:updatedAt)
    assert_equal [ { color: "W", weight: 2 }, { color: "U", weight: 1 } ], deck.fetch(:colorBands)
  end

  test "expands included cards and excludes sideboards" do
    client = StubClient.new(
      "name" => "Landfall",
      "categories" => [
        { "name" => "Main", "includedInDeck" => true },
        { "name" => "Maybeboard", "includedInDeck" => false }
      ],
      "cards" => [
        {
          "quantity" => 2,
          "categories" => [ "Main" ],
          "card" => {
            "uid" => "92b0be6d-9183-4938-b7a1-ae7f04ba78a0",
            "displayName" => "Forest",
            "oracleCard" => { "typeLine" => "Basic Land — Forest", "text" => "" }
          }
        },
        {
          "quantity" => 1,
          "categories" => [ "Sideboard" ],
          "card" => {
            "uid" => "sideboard-card",
            "displayName" => "Sideboard Card",
            "oracleCard" => { "typeLine" => "Instant", "text" => "" }
          }
        },
        {
          "quantity" => 1,
          "categories" => [ "Maybeboard" ],
          "card" => {
            "uid" => "maybeboard-card",
            "displayName" => "Maybeboard Card",
            "oracleCard" => { "typeLine" => "Creature", "text" => "" }
          }
        }
      ]
    )

    deck = client.deck("123")

    assert_equal "Landfall", deck.fetch(:name)
    assert_equal 2, deck.fetch(:cards).length
    assert deck.fetch(:cards).all? { |card| card.fetch("name") == "Forest" }
    assert deck.fetch(:cards).all? { |card| card.fetch("is_mana_source") }
    assert_match %r{/9/2/92b0be6d-9183-4938-b7a1-ae7f04ba78a0\.jpg\z},
      deck.dig(:cards, 0, "image_url")
  end
end
