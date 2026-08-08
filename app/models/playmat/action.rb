class Playmat::Action
  ZONE_NAMES = %w[library hand battlefield graveyard exile].to_set.freeze
  DECK_POSITIONS = %w[top bottom shuffle].to_set.freeze
  NUMERIC_ATTRIBUTE_NAMES = %w[count delta value x y].freeze

  attr_reader :attributes, :type

  def self.parse(raw_action)
    return unless raw_action.respond_to?(:to_h)

    attributes = normalize_numeric_attributes(
      raw_action.to_h.deep_transform_keys { |key| key.to_s.underscore }
    )
    type = attributes["type"]
    return unless type.is_a?(String)

    new(type:, attributes:) if valid?(type, attributes)
  end

  def self.valid?(type, attributes)
    case type
    when "draw_card"
      attributes["count"].nil? || finite_number?(attributes["count"])
    when "shuffle_library", "untap_all", "reset_life", "open_deck_search", "close_deck_search",
      "open_library_search", "close_library_search"
      true
    when "move_library_card_to_hand", "play_from_hand", "toggle_tap"
      text_identifier?(attributes["instance_id"])
    when "move_battlefield_card"
      text_identifier?(attributes["instance_id"]) &&
        finite_number?(attributes["x"]) &&
        finite_number?(attributes["y"])
    when "move_card_zone"
      valid_zone_move?(attributes)
    when "move_to_deck"
      text_identifier?(attributes["instance_id"]) &&
        ZONE_NAMES.include?(attributes["from"]) &&
        DECK_POSITIONS.include?(attributes["position"])
    when "adjust_life"
      finite_number?(attributes["delta"])
    when "set_life"
      finite_number?(attributes["value"])
    when "add_counter"
      valid_counter_addition?(attributes)
    when "move_counter"
      text_identifier?(attributes["instance_id"]) &&
        text_identifier?(attributes["counter_id"]) &&
        finite_number?(attributes["x"]) &&
        finite_number?(attributes["y"])
    when "update_counter_value"
      text_identifier?(attributes["instance_id"]) &&
        text_identifier?(attributes["counter_id"]) &&
        finite_number?(attributes["delta"])
    else
      false
    end
  end

  def self.valid_zone_move?(attributes)
    return false unless text_identifier?(attributes["instance_id"])
    return false unless ZONE_NAMES.include?(attributes["from"])
    return false unless ZONE_NAMES.include?(attributes["to"])
    return false if attributes.key?("x") && !finite_number?(attributes["x"])
    return false if attributes.key?("y") && !finite_number?(attributes["y"])

    true
  end

  def self.valid_counter_addition?(attributes)
    return false unless text_identifier?(attributes["instance_id"])
    return false unless finite_number?(attributes["x"])
    return false unless finite_number?(attributes["y"])

    !attributes.key?("label") || attributes["label"].is_a?(String)
  end

  def self.finite_number?(value)
    value.is_a?(Numeric) && (!value.respond_to?(:finite?) || value.finite?)
  end

  def self.normalize_numeric_attributes(attributes)
    attributes.to_h do |name, value|
      [ name, normalize_numeric_attribute(name, value) ]
    end
  end

  def self.normalize_numeric_attribute(name, value)
    return value unless NUMERIC_ATTRIBUTE_NAMES.include?(name) && value.is_a?(String)

    Float(value, exception: false) || value
  end

  def self.text_identifier?(value)
    value.is_a?(String) && value.strip.present?
  end

  private_class_method :finite_number?,
    :normalize_numeric_attributes,
    :normalize_numeric_attribute,
    :text_identifier?,
    :valid_counter_addition?,
    :valid_zone_move?

  def initialize(type:, attributes:)
    @type = normalize_type(type)
    @attributes = attributes.freeze
    freeze
  end

  def [](name)
    attributes[name.to_s]
  end

  private

  def normalize_type(type)
    case type
    when "open_library_search"
      "open_deck_search"
    when "close_library_search"
      "close_deck_search"
    else
      type
    end
  end
end
