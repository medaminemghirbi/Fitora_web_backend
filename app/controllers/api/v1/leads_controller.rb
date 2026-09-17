module Api
  module V1
    # Where a gym asks to work with Fitora. Unauthenticated by design: the
    # whole point is that no account exists yet. Write-only from outside —
    # a prospect can post a request and never read one back.
    class LeadsController < ApplicationController
      def create
        lead = Lead.new(lead_params)

        if lead.save
          render json: { lead: { id: lead.id, kind: lead.kind } }, status: :created
        else
          render json: { error: lead.errors.full_messages.first, errors: lead.errors.full_messages }, status: :unprocessable_content
        end
      end

      private

      # `status`, the internal notes and who handled it are never settable
      # from here — they belong to whoever answers the request.
      def lead_params
        params.require(:lead).permit(:kind, :contact_name, :gym_name, :email, :phone, :city, :locale, :message)
      end
    end
  end
end
