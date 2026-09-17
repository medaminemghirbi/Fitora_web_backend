module Api
  module V1
    module Me
      # The gyms the signed-in person belongs to, and joining or leaving one.
      # Joining is instant: there is nothing for the gym to approve.
      class GymsController < BaseController
        before_action :require_client!

        # GET /api/v1/me/gyms
        def index
          render json: { gyms: current_client.memberships.includes(:company).map { |m| membership_json(m) } }
        end

        # POST /api/v1/me/gyms { gym_id: }
        def create
          gym = Company.listed.find_by(id: params[:gym_id])
          return render json: { error: "Gym not found" }, status: :not_found if gym.nil?

          membership = current_client.join!(gym)
          render json: { gym: membership_json(membership) }, status: :created
        end

        # DELETE /api/v1/me/gyms/:id — leaving hides the gym from the
        # person's app. The gym keeps its own records (contracts, payments,
        # attendance): those are its books, not the person's to erase.
        def destroy
          membership = current_client.memberships.find_by(company_id: params[:id])
          return render json: { error: "Gym not found" }, status: :not_found if membership.nil?

          membership.destroy
          head :no_content
        end

        private

        def membership_json(membership)
          GymSerializer.new(membership.company).as_json.merge(
            joined_at: membership.joined_at,
            active: membership.active,
            current_contract: ContractSerializer.new(current_client.current_contract(membership.company)).as_json
          )
        end
      end
    end
  end
end
