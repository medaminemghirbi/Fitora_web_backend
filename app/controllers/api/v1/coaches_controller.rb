module Api
  module V1
    class CoachesController < BaseController
      before_action :require_company!
      # The coach list is schedule reference data (assign a coach to a
      # session); managing coach records is the :coaches capability.
      before_action -> { require_schedule_reference_read!(:coaches) }, only: [ :index, :show ]
      before_action -> { require_capability!(:coaches) }, only: [ :create, :update, :destroy, :set_login ]
      before_action :set_coach, only: [ :show, :update, :destroy, :set_login ]

      # GET /api/v1/coaches
      def index
        render json: { coaches: current_company.coaches.order(:first_name).map { |c| CoachSerializer.new(c).as_json } }
      end

      # GET /api/v1/coaches/:id
      def show
        render json: { coach: CoachSerializer.new(@coach).as_json }
      end

      # POST /api/v1/coaches — auto-assigned to the company's one location
      def create
        coach = current_company.coaches.new(coach_params)

        if coach.save
          coach.coach_locations.create!(location: current_company.location)
          render json: { coach: CoachSerializer.new(coach.reload).as_json }, status: :created
        else
          render json: { error: coach.errors.full_messages.first, errors: coach.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/coaches/:id
      def update
        if @coach.update(coach_params)
          render json: { coach: CoachSerializer.new(@coach).as_json }
        else
          render json: { error: @coach.errors.full_messages.first, errors: @coach.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/coaches/:id — soft deactivate
      def destroy
        @coach.update!(active: false)
        render json: { coach: CoachSerializer.new(@coach).as_json }
      end

      # POST /api/v1/coaches/:id/login — provisions (or resets) the coach's
      # own mobile-app login. Owner and manager already reach this via the
      # blanket :coaches capability; this is also how a receptionist gets to
      # do it, without being handed general staff management.
      def set_login
        result = Coaches::SetLogin.call(coach: @coach, email: params[:email], password: params[:password])

        if result.success?
          AuditLogs::Record.call(
            company: current_company, user: current_user, action: "coach.login_set",
            auditable: @coach, metadata: { email: params[:email] }
          )
          render json: { coach: CoachSerializer.new(@coach.reload).as_json }
        else
          render json: { error: result.error }, status: :unprocessable_entity
        end
      end

      private

      def set_coach
        @coach = current_company.coaches.find(params[:id])
      end

      def coach_params
        params.require(:coach).permit(:first_name, :last_name, :email, :phone, :bio, :photo_url, :active, :birthdate)
      end
    end
  end
end
