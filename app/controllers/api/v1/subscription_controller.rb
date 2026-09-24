module Api
  module V1
    # The gym's own view of its Gymly access: whether it is open, until
    # when, and every invoice it has been issued.
    #
    # There is nothing to ask for here any more. A gym settles with Gymly
    # directly; Gymly confirms, and the invoice appears.
    class SubscriptionController < BaseController
      before_action :require_admin!

      # GET /api/v1/subscription
      def show
        render json: SubscriptionStatusSerializer.new(company: current_company, admin: current_user).as_json
      end
    end
  end
end
