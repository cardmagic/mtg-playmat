module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :playmat_session_id

    def connect
      self.playmat_session_id = cookies.signed[Playmat::SESSION_COOKIE]
      reject_unauthorized_connection if playmat_session_id.blank?
    end
  end
end
