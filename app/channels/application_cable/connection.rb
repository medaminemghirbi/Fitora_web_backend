module ApplicationCable
  # Opens with a cable ticket (POST /api/v1/cable_ticket): browsers can't set
  # headers on a WebSocket handshake, so the credential rides in the query
  # string (?ticket=...). A ticket lasts 30 seconds and opens one connection,
  # so the copy that access logs keep is worthless — unlike the login token
  # that used to travel here.
  #
  # A connection is either a User's (admin, superadmin) or a Client's (a member on
  # their own app), never both.
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :current_client

    def connect
      claims = verified_ticket
      if claims[:client_id]
        self.current_client = find_current(Client, claims)
      else
        self.current_user = find_current(User, claims)
      end
    end

    private

    def verified_ticket
      ticket = request.params[:ticket].to_s
      reject_unauthorized_connection if ticket.blank?

      claims = JwtService.decode_cable_ticket(ticket)
      reject_unauthorized_connection unless first_use?(claims[:jti])
      claims
    rescue JwtService::DecodeError
      reject_unauthorized_connection
    end

    def find_current(model, claims)
      account = model.active.find_by(id: claims[:client_id] || claims[:user_id])
      return account if account&.token_current?(claims[:token_version])

      reject_unauthorized_connection
    end

    # Redis remembers each ticket past its expiry, so a replay within the
    # 30 seconds is refused too.
    def first_use?(jti)
      return false if jti.blank?

      Sidekiq.redis { |redis| redis.call("SET", "cable_ticket:#{jti}", "1", "NX", "EX", 60) } == "OK"
    end
  end
end
