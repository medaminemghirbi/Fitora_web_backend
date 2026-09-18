module Api
  module V1
    class AuthController < ApplicationController
      before_action :authenticate_request!, only: [ :me, :logout, :permissions ]

      # POST /api/v1/auth/login — one door for both kinds of account.
      #
      # A platform account first (owner, staff, Fitora admin), then a member
      # whose gym enabled their access. account_type says which came back, so
      # the caller sends them to the right home without asking who they are
      # first. Nobody signs themselves up either way: a gym asks for a demo or
      # a quote (Leads::Convert), and a member's access is switched on from
      # their own file by the gym.
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
