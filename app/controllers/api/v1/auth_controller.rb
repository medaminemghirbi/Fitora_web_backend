module Api
  module V1
    class AuthController < ApplicationController
      before_action :authenticate_request!, only: [ :me, :logout, :permissions ]

      # POST /api/v1/auth/register — a gym signing up for Fitora. Every other
      # account (manager/receptionist/coach) is created by the owner via
      # StaffController, never self-registered.
      def register
        user = User.new(
          first_name: params[:first_name],
          last_name: params[:last_name],
          email: params[:email],
          phone: params[:phone],
          password: params[:password],
          role: :owner,
          locale: params[:locale].presence || "fr"
        )

        if user.save
          raw = user.generate_email_verification_token!
          AccountMailer.email_verification(user, raw).deliver_later
          render json: { token: JwtService.encode(user.id), user: UserSerializer.new(user).as_json }, status: :created
        else
          render json: { error: user.errors.full_messages.first, errors: user.errors.full_messages }, status: :unprocessable_entity
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
