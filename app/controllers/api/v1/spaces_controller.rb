module Api
  module V1
    # The gym's rooms. Only meaningful once the company has turned spaces on
    # (CompanySettings FEATURES[:spaces]) — a gym that has not sees no room
    # anywhere in its UI.
    #
    # Reading is open to whoever owns the room catalogue OR can edit the
    # schedule, for the same reason activities are: you cannot plan a week of
    # sessions without seeing which rooms they can go in.
    class SpacesController < BaseController
      before_action :require_company!
      before_action :require_spaces_enabled!
      before_action -> { require_schedule_reference_read!(:spaces) }, only: [ :index, :show ]
      before_action -> { require_capability!(:spaces) }, only: [ :create, :update, :destroy ]
      before_action :set_space, only: [ :show, :update, :destroy ]

      # GET /api/v1/spaces
      def index
        scope = current_company.spaces.search(params[:q]).ordered
        scope = scope.active if params[:active] == "true"

        render json: {
          spaces: scope.includes(:activities).map { |s| SpaceSerializer.new(s).as_json },
          meta: { total: scope.count }
        }
      end

      # GET /api/v1/spaces/:id
      def show
        render json: { space: SpaceSerializer.new(@space).as_json }
      end

      # POST /api/v1/spaces
      def create
        space = current_company.spaces.new(space_params)

        if space.save
          sync_activities(space)
          render json: { space: SpaceSerializer.new(space.reload).as_json }, status: :created
        else
          render_invalid(space)
        end
      end

      # PATCH /api/v1/spaces/:id
      def update
        if @space.update(space_params)
          sync_activities(@space)
          render json: { space: SpaceSerializer.new(@space.reload).as_json }
        else
          render_invalid(@space)
        end
      end

      # DELETE /api/v1/spaces/:id
      #
      # Deactivates rather than deletes while anything is still scheduled in
      # the room: a room going out of use is not a reason to lose the record
      # of what happened in it. Once nothing upcoming needs it, it goes for
      # real — and past sessions keep their history with the room unset.
      def destroy
        if @space.deletable?
          @space.destroy!
        else
          @space.update!(active: false)
        end

        render json: { space: SpaceSerializer.new(@space).as_json }
      end

      private

      def set_space
        @space = current_company.spaces.find(params[:id])
      end

      # Replaces the set of activities restricted to this room. Scoped to the
      # company's own activities, so a foreign id is dropped rather than
      # linked.
      def sync_activities(space)
        return unless params[:space].key?(:activity_ids)

        ids = current_company.activities.where(id: Array(params[:space][:activity_ids])).pluck(:id)
        space.activity_ids = ids
      end

      def space_params
        params.require(:space).permit(:name, :kind, :capacity, :active)
      end

      def render_invalid(record)
        render json: { error: record.errors.full_messages.first, errors: record.errors.full_messages },
               status: :unprocessable_content
      end

      # A company that has not turned rooms on has no rooms to talk about.
      # 404 rather than 403: the feature is absent for them, not forbidden.
      def require_spaces_enabled!
        return if current_company.feature?(:spaces)

        render json: { error: "Rooms are not enabled for this gym" }, status: :not_found
      end
    end
  end
end
