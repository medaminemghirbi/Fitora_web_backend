module Api
  module V1
    # Confirms an email is real. For an owner that is what opens the account
    # (Api::V1::BaseController#require_confirmed_email!); for anyone else it
    # is informational. Never for a platform admin (role: :admin), same
    # exclusion as PasswordResetsController.
    class EmailVerificationsController < ApplicationController
      before_action :authenticate_request!, only: [ :create ]

      # POST /api/v1/email_verifications — resend, for the signed-in
      # user/client.
      def create
        record = current_client || current_user
        return render_forbidden if record.nil? || (record.is_a?(User) && record.admin?)
        return render(json: { error: "no_email" }, status: :unprocessable_content) if record.email.blank?
        return render(json: { error: "already_verified" }, status: :unprocessable_content) if record.email_verified?

        wait = record.email_verification_resend_in
        return render(json: { error: "too_soon", retry_in: wait }, status: :too_many_requests) if wait.positive?

        raw = record.generate_email_verification_token!
        AccountMailer.email_verification(record, raw).deliver_later
        head :no_content
      end

      # PATCH /api/v1/email_verifications/:token — unauthenticated: the
      # token itself, from the emailed link, is the proof.
      def update
        record = User.where.not(role: :admin).find_by_email_verification_token(params[:token]) ||
                 Client.find_by_email_verification_token(params[:token])

        return render(json: { error: "invalid_or_expired_token" }, status: :unprocessable_content) if record.nil?

        record.verify_email!
        head :no_content
      end
    end
  end
end
