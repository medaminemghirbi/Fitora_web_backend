module ApplicationCable
  # Authenticates the WebSocket the same way ApplicationController does for
  # HTTP: a JWT. Browsers can't set headers on a WS handshake, so the token
  # rides in the query string (?token=...) — same-origin, same secret.
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private

    def find_verified_user
      token = request.params[:token].to_s
      reject_unauthorized_connection if token.blank?

      claims = JwtService.decode(token)
      user = User.active.find_by(id: claims[:user_id])
      user || reject_unauthorized_connection
    rescue JwtService::DecodeError
      reject_unauthorized_connection
    end
  end
end
