module Api
  module V1
    # Confirms an email is real — informational, never blocks login. Never
    # for a platform admin (role: :admin), same exclusion as PasswordResetsController.
    class EmailVerificationsController < ApplicationController
      before_action :authenticate_request!, only: [ :create ]

      # POST /api/v1/email_verifications — resend, for the signed-in
      # user/client.
      def create
        record = current_user
        return render_forbidden if record.nil? || (record.is_a?(User) && record.admin?)
        return render(json: { error: "no_email" }, status: :unprocessable_content) if record.email.blank?
        return render(json: { error: "already_verified" }, status: :unprocessable_content) if record.email_verified?

        raw = record.generate_email_verification_token!
        AccountMailer.email_verification(record, raw).deliver_later
        head :no_content
      end

      # PATCH /api/v1/email_verifications/:token — unauthenticated: the
      # token itself, from the emailed link, is the proof.
      def update
        record = User.where.not(role: :admin).find_by_email_verification_token(params[:token])

        return render(json: { error: "invalid_or_expired_token" }, status: :unprocessable_content) if record.nil?

        record.verify_email!
        head :no_content
      end
    end
  end
end
