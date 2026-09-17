module Api
  module V1
    module Admin
      # The Fitora inbox for demo and quote requests: the front door of the
      # B2B funnel now that a gym cannot open its own account.
      class LeadsController < BaseController
        before_action :require_admin!
        before_action :set_lead, only: [ :update, :convert ]

        # GET /api/v1/admin/leads?status=
        def index
          leads = Lead.recent
          leads = leads.where(status: params[:status]) if params[:status].present?

          render json: {
            leads: leads.map { |l| LeadSerializer.new(l).as_json },
            counts: Lead.group(:status).count.merge("all" => Lead.count)
          }
        end

        # PATCH /api/v1/admin/leads/:id — move it along the funnel, and keep
        # a note of what was said.
        def update
          @lead.assign_attributes(lead_params)
          @lead.handled_by = current_user
          @lead.handled_at ||= Time.current

          if @lead.save
            render json: { lead: LeadSerializer.new(@lead).as_json }
          else
            render json: { error: @lead.errors.full_messages.first, errors: @lead.errors.full_messages }, status: :unprocessable_content
          end
        end

        # POST /api/v1/admin/leads/:id/convert — opens the account for a gym
        # whose request has been answered, and hands back the first password
        # for the admin to pass on.
        def convert
          result = Leads::Convert.call(lead: @lead, admin: current_user)

          if result.success?
            render json: {
              lead: LeadSerializer.new(result.lead.reload).as_json,
              company: { id: result.company.id, name: result.company.name },
              owner: { id: result.owner.id, email: result.owner.email },
              temporary_password: result.password
            }, status: :created
          else
            render json: { error: result.error }, status: :unprocessable_content
          end
        end

        private

        def set_lead
          @lead = Lead.find(params[:id])
        end

        def lead_params
          params.require(:lead).permit(:status, :internal_notes)
        end
      end
    end
  end
end
