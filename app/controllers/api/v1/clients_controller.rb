module Api
  module V1
    class ClientsController < BaseController
      before_action :require_company!
      before_action -> { require_capability!(:clients) }
      before_action :set_client, only: [ :show, :update ]

      # GET /api/v1/clients?search=&status=&page=
      # status: active | inactive | contract_active | contract_expired | no_contract
      def index
        clients = filtered_scope.order(:first_name, :last_name)

        if params[:format] == "csv"
          send_data clients_csv(clients), filename: "clients-#{Date.current}.csv"
        else
          render json: {
            clients: paginate(clients).map { |c| ClientSerializer.new(c).as_json },
            meta: pagination_meta(clients)
          }
        end
      end

      # GET /api/v1/clients/:id
      def show
        render json: {
          client: ClientSerializer.new(@client, detailed: true).as_json,
          contracts: @client.contracts.includes(:contract_type).order(created_at: :desc).map { |m| ContractSerializer.new(m).as_json },
          bookings: @client.bookings.includes(session: [ :activity, :location, :coach ]).order(created_at: :desc).limit(20).map { |b| BookingSerializer.new(b).as_json },
          payments: @client.payments.recent.limit(20).map { |p| PaymentSerializer.new(p).as_json }
        }
      end

      # POST /api/v1/clients
      def create
        client = current_company.clients.new(client_params)

        if client.save
          render json: { client: ClientSerializer.new(client).as_json }, status: :created
        else
          render json: { error: client.errors.full_messages.first, errors: client.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/clients/:id
      def update
        login_newly_enabled = @client.password_digest.blank? && client_params[:password].present?

        if @client.update(client_params)
          if login_newly_enabled && @client.email.present?
            raw = @client.generate_email_verification_token!
            AccountMailer.email_verification(@client, raw).deliver_later
          end
          render json: { client: ClientSerializer.new(@client).as_json }
        else
          render json: { error: @client.errors.full_messages.first, errors: @client.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_client
        @client = current_company.clients.find(params[:id])
      end

      def filtered_scope
        scope = current_company.clients.search(params[:search])

        case params[:status]
        when "active" then scope.active
        when "inactive" then scope.where(active: false)
        when "contract_active" then scope.joins(:contract_periods).merge(ContractPeriod.currently_active).distinct
        when "contract_expired" then scope.joins(:contract_periods).merge(ContractPeriod.where(status: :expired)).distinct
        when "no_contract" then scope.where.missing(:contracts)
        else scope
        end
      end

      def clients_csv(clients)
        CSV.generate do |csv|
          csv << [ "First name", "Last name", "Email", "Phone", "Active", "Joined at" ]
          clients.find_each do |c|
            csv << [ c.first_name, c.last_name, c.email, c.phone, c.active, c.joined_at ]
          end
        end
      end

      def client_params
        params.require(:client).permit(
          :first_name, :last_name, :email, :phone, :date_of_birth, :gender,
          :address, :emergency_contact_name, :emergency_contact_phone, :notes, :active,
          :password
        )
      end
    end
  end
end
