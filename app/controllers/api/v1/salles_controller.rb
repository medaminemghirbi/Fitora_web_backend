module Api
  module V1
    # Salles ("rooms") — a location's physical spaces, shown with photos.
    # Read is open to any active staff member (same reasoning as the
    # schedule: shared operational context, not a privileged view);
    # managing them requires the same capability as the location itself.
    class SallesController < BaseController
      before_action :require_company!
      before_action :require_staff!, only: [ :index, :show ]
      before_action -> { require_capability!(:locations) }, only: [ :create, :update, :destroy ]
      before_action :set_salle, only: [ :show, :update, :destroy ]

      # GET /api/v1/salles
      def index
        scope = Salle.joins(:location).where(locations: { company_id: current_company.id })
        render json: { salles: scope.order(:name).map { |s| SalleSerializer.new(s).as_json } }
      end

      # GET /api/v1/salles/:id
      def show
        render json: { salle: SalleSerializer.new(@salle).as_json }
      end

      # POST /api/v1/salles (multipart/form-data — :images accepts multiple files)
      def create
        salle = current_company.location.salles.new(salle_params)

        if salle.save
          render json: { salle: SalleSerializer.new(salle).as_json }, status: :created
        else
          render json: { error: salle.errors.full_messages.first, errors: salle.errors.full_messages }, status: :unprocessable_content
        end
      end

      # PATCH /api/v1/salles/:id — omitting :images leaves the existing
      # gallery untouched; sending :images replaces it entirely.
      def update
        if @salle.update(salle_params)
          render json: { salle: SalleSerializer.new(@salle).as_json }
        else
          render json: { error: @salle.errors.full_messages.first, errors: @salle.errors.full_messages }, status: :unprocessable_content
        end
      end

      # DELETE /api/v1/salles/:id — soft deactivate, same convention as Activity.
      def destroy
        @salle.update!(active: false)
        render json: { salle: SalleSerializer.new(@salle).as_json }
      end

      private

      def set_salle
        @salle = Salle.joins(:location)
                       .where(locations: { company_id: current_company.id })
                       .find(params[:id])
      end

      def salle_params
        params.require(:salle).permit(:name, :description, :capacity, :active, images: [])
      end
    end
  end
end
