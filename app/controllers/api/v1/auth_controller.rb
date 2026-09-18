module Api
  module V1
    class AuthController < ApplicationController
      before_action :authenticate_request!, only: [ :me, :logout, :permissions ]

      # POST /api/v1/auth/login
      #
      # Only a platform account signs in: an owner, their staff, or a Fitora
      # admin. A gym's members are records its staff manage — they have no
      # account here, and no self-signup either (a gym asks for a demo or a
      # quote, and Leads::Convert opens the account).
      #
      # account_type is still emitted so existing clients keep parsing the
      # response the same way.
      def login
        email = params[:email].to_s.downcase.strip

        user = User.active.find_by(email: email)
        if user&.authenticate(params[:password])
          return render json: { token: JwtService.encode(user.id), account_type: "user", user: UserSerializer.new(user).as_json }
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
        render json: { account_type: "user", user: UserSerializer.new(current_user).as_json }
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
