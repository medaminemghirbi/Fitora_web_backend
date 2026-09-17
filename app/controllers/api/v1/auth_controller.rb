module Api
  module V1
    class AuthController < ApplicationController
      before_action :authenticate_request!, only: [ :me, :logout, :permissions ]

      # A gym cannot sign itself up: it asks for a demo or a quote
      # (Api::V1::LeadsController) and a Fitora admin opens the account once
      # the conversation has happened (Leads::Convert). The only
      # self-registration left is a person looking for a gym.
      #
      # POST /api/v1/auth/register_client — a person signing themselves up.
      # No gym involved: they pick their gyms afterwards from the directory.
      # An email that a gym already recorded (a walk-in with no login) claims
      # THAT account rather than making a second one, so their history at
      # that gym follows them.
      def register_client
        email = params[:email].to_s.downcase.strip
        client = Client.find_by_email(email)

        if client&.login_enabled?
          return render json: { error: "An account already exists for this email" }, status: :unprocessable_content
        end

        client ||= Client.new(email: email)
        client.assign_attributes(
          first_name: params[:first_name],
          last_name: params[:last_name],
          phone: params[:phone].presence || client.phone,
          password: params[:password]
        )

        if client.save
          raw = client.generate_email_verification_token!
          AccountMailer.email_verification(client, raw).deliver_later
          render json: {
            token: JwtService.encode(client_id: client.id),
            account_type: "client",
            client: ClientSerializer.new(client).as_json
          }, status: :created
        else
          render json: { error: client.errors.full_messages.first, errors: client.errors.full_messages }, status: :unprocessable_content
        end
      end

      # POST /api/v1/auth/login — tries a platform account (owner/staff/
      # admin) first, then a client's own mobile login. account_type in the
      # response tells the caller which kind of session it got.
      def login
        email = params[:email].to_s.downcase.strip

        user = User.active.find_by(email: email)
        if user&.authenticate(params[:password])
          return render json: { token: JwtService.encode(user.id), account_type: "user", user: UserSerializer.new(user).as_json }
        end

        client = Client.active.where.not(password_digest: nil).find_by(email: email)
        if client&.authenticate(params[:password])
          return render json: { token: JwtService.encode(client_id: client.id), account_type: "client", client: ClientSerializer.new(client).as_json }
        end

        render json: { error: "Invalid email or password" }, status: :unauthorized
      end

      # POST /api/v1/auth/logout
      def logout
        # Stateless JWT — nothing to invalidate server-side in V0; the client discards the token.
        head :no_content
      end

      # GET /api/v1/auth/me
      def me
        if current_client
          render json: { account_type: "client", client: ClientSerializer.new(current_client).as_json }
        else
          render json: { account_type: "user", user: UserSerializer.new(current_user).as_json }
        end
      end

      # GET /api/v1/me/permissions — the resolved capability list for the
      # signed-in staff login, plus the role it came from. The frontend
      # renders navigation and guards page access from this rather than a
      # hard-coded map. Owners get every permission; a platform admin gets
      # none (the /admin surface isn't capability-gated).
      def permissions
        resolved = Permissions::Resolve.call(user: current_user)
        render json: { role: resolved.role, permissions: resolved.permissions }
      end
    end
  end
end
