module Api
  module V1
    class RecurringSchedulesController < BaseController
      before_action :require_company!
      before_action -> { require_capability!(:sessions) }, only: [ :index, :create, :update ]
      before_action :set_schedule, only: [ :update ]

      # GET /api/v1/recurring_schedules
      def index
        schedules = current_company.recurring_schedules.includes(:activity, :location, :coach).order(:starts_on)
        render json: { recurring_schedules: schedules.map { |s| RecurringScheduleSerializer.new(s).as_json } }
      end

      # POST /api/v1/recurring_schedules
      def create
        activity = Activity.joins(:location)
                            .where(locations: { company_id: current_company.id })
                            .find_by(id: schedule_params[:activity_id])
        return render json: { error: "Activity not found" }, status: :not_found if activity.nil?

        schedule = current_company.recurring_schedules.new(schedule_params.merge(location_id: activity.location_id))

        if schedule.save
          generation = RecurringSchedules::Generate.call(schedule: schedule)
          render json: {
            recurring_schedule: RecurringScheduleSerializer.new(schedule.reload).as_json,
            generated: generation.created_count,
            skipped: generation.skipped_count,
            conflicts: generation.conflict_errors
          }, status: :created
        else
          render json: { error: schedule.errors.full_messages.first, errors: schedule.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/recurring_schedules/:id — active flag only (stopping a
      # series); changing the recurrence pattern itself means creating a new
      # schedule, so past-generated sessions never silently shift.
      def update
        if @schedule.update(params.permit(:active))
          render json: { recurring_schedule: RecurringScheduleSerializer.new(@schedule).as_json }
        else
          render json: { error: @schedule.errors.full_messages.first, errors: @schedule.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_schedule
        @schedule = current_company.recurring_schedules.find(params[:id])
      end

      def schedule_params
        params.require(:recurring_schedule).permit(:activity_id, :coach_id, :start_time, :recurrence_type, :starts_on, :ends_on, weekdays: [])
      end
    end
  end
end
