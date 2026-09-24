module Api
  module V1
    # A member accepting the invitation their gym sent — unauthenticated by
    # design, like PasswordResetsController: the emailed token is the proof.
    class InvitationsController < ApplicationController
      # PATCH /api/v1/invitations/:token — { password: }
      def update
        client = Client.active.find_by_invitation_token(params[:token])
        return render(json: { error: "invalid_or_expired_token" }, status: :unprocessable_content) if client.nil?

        if client.accept_invitation!(params[:password])
          head :no_content
        else
          render_errors(client)
        end
      end
    end
  end
end
