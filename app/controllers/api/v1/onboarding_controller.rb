module Api
  module V1
    # The owner-only "Premiers pas" getting-started guide. Its checklist is
    # read from the bootstrap payload (`setup`); this endpoint only lets the
    # owner dismiss it.
    class OnboardingController < BaseController
      before_action :require_owner!
      before_action :require_company!

      # POST /api/v1/onboarding/dismiss
      def dismiss
        current_company.update!(setup_dismissed_at: Time.current)
        render json: { setup: current_company.setup_state }
      end
    end
  end
end
