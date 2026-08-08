class Playmat::RoomCode
  ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".chars.freeze
  LENGTH = 6

  def self.generate
    Array.new(LENGTH) { ALPHABET.sample }.join
  end

  def self.normalize(value)
    value.to_s.upcase.gsub(/[^A-Z0-9]/, "").first(LENGTH)
  end
end
