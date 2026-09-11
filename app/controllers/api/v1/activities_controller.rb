module Api
  module V1
    class ActivitiesController < BaseController
      before_action :require_company!
      before_action -> { require_schedule_reference_read!(:activities) }, only: [ :index, :show ]
      before_action -> { require_capability!(:activities) }, only: [ :create, :update, :destroy ]
      before_action :set_activity, only: [ :show, :update, :destroy ]

      # GET /api/v1/activities
      def index
        scope = Activity.joins(:location).where(locations: { company_id: current_company.id })
        render json: { activities: scope.order(:name).map { |a| ActivitySerializer.new(a).as_json } }
      end

      # GET /api/v1/activities/:id
      def show
        render json: { activity: ActivitySerializer.new(@activity).as_json }
      end

      # POST /api/v1/activities — always attaches to the company's one location
      def create
        activity = current_company.location.activities.new(activity_params)

        if activity.save
          render json: { activity: ActivitySerializer.new(activity).as_json }, status: :created
        else
          render json: { error: activity.errors.full_messages.first, errors: activity.errors.full_messages }, status: :unprocessable_content
        end
      end

      # PATCH /api/v1/activities/:id
      def update
        if @activity.update(activity_params)
          render json: { activity: ActivitySerializer.new(@activity).as_json }
        else
          render json: { error: @activity.errors.full_messages.first, errors: @activity.errors.full_messages }, status: :unprocessable_content
        end
      end

      # DELETE /api/v1/activities/:id — soft deactivate
      def destroy
        @activity.update!(active: false)
        render json: { activity: ActivitySerializer.new(@activity).as_json }
      end

      private

      def set_activity
        @activity = Activity.joins(:location)
                             .where(locations: { company_id: current_company.id })
                             .find(params[:id])
      end

      def activity_params
        params.require(:activity).permit(
          :name, :emoji, :description, :session_format, :duration, :capacity, :active
        )
      end
    end
  end
end
