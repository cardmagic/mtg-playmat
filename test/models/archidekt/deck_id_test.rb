require "test_helper"

class Archidekt::DeckIdTest < ActiveSupport::TestCase
  test "accepts raw identifiers and Archidekt URLs" do
    assert_equal "18476272", Archidekt::DeckId.extract("18476272")
    assert_equal "18476272", Archidekt::DeckId.extract("https://archidekt.com/decks/18476272/my-deck")
  end

  test "rejects invalid identifiers" do
    assert_nil Archidekt::DeckId.extract("")
    assert_nil Archidekt::DeckId.extract("https://example.com/deck")
  end
end
