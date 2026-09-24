module Api
  module V1
    module Me
      # A member leaving Gymly. Their password confirms it; the gyms keep
      # their books, and nothing on them names this person any more
      # (Clients::Anonymise).
      class AccountsController < BaseController
        before_action :require_client!

        # DELETE /api/v1/me/account — { password: }
        def destroy
          unless current_client.authenticate(params[:password].to_s)
            return render json: { error: "password_invalid", errors: [ "Password is incorrect" ] }, status: :unprocessable_content
          end

          Clients::Anonymise.call(client: current_client)
          head :no_content
        end
      end
    end
  end
end
