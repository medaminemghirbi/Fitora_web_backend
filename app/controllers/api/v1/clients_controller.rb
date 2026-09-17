module Api
  module V1
    class ClientsController < BaseController
      before_action :require_company!
      before_action -> { require_capability!(:clients) }
      before_action :set_client, only: [ :show, :update ]

      STATUS_FILTERS = %w[active inactive contract_active contract_expired no_contract].freeze

      # GET /api/v1/clients?search=&status=&page=
      # status: active | inactive | contract_active | contract_expired | no_contract
      def index
        searched = current_company.clients.search(params[:search])
        clients = status_scope(searched, params[:status]).order(:first_name, :last_name)

        if params[:format] == "csv"
          send_data clients_csv(clients), filename: "clients-#{Date.current}.csv"
        else
          render json: {
            clients: paginate(clients).map { |c| ClientSerializer.new(c, company: current_company).as_json },
            meta: pagination_meta(clients),
            counts: status_counts(searched)
          }
        end
      end

      # GET /api/v1/clients/:id
      def show
        render json: {
          client: ClientSerializer.new(@client, detailed: true, company: current_company).as_json,
          contracts: @client.contracts_for(current_company).includes(:contract_type).order(created_at: :desc).map { |m| ContractSerializer.new(m).as_json },
          bookings: @client.bookings_for(current_company).includes(session: [ :activity, :coach ]).order(created_at: :desc).limit(20).map { |b| BookingSerializer.new(b).as_json },
          payments: @client.payments_for(current_company).recent.limit(20).map { |p| PaymentSerializer.new(p).as_json }
        }
      end

      # POST /api/v1/clients — adds someone to THIS gym. The email identifies
      # the person across the platform, so an address that already has an
      # account joins that person rather than creating a second one. Their
      # identity is theirs: we only fill in what the account left blank, and
      # never overwrite a name or a phone the person set themselves.
      def create
        existing = Client.find_by_email(client_params[:email])
        client = existing || Client.new
        client.assign_attributes(existing ? fill_blanks_only(client, person_params) : person_params)

        ActiveRecord::Base.transaction do
          client.save!
          membership = client.join!(current_company)
          membership.update!(membership_params) if membership_params.any?
        end

        AuditLogs::Record.call(
          company: current_company, user: current_user,
          action: existing ? "client.joined" : "client.created",
          auditable: client, metadata: { name: client.full_name }
        )
        render json: { client: ClientSerializer.new(client, company: current_company).as_json }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.record.errors.full_messages.first, errors: e.record.errors.full_messages }, status: :unprocessable_content
      end

      # PATCH /api/v1/clients/:id
      def update
        login_newly_enabled = @client.password_digest.blank? && client_params[:password].present?
        membership = @client.membership_for(current_company)
        membership&.update(membership_params) if membership_params.any?

        if @client.update(person_params)
          if login_newly_enabled && @client.email.present?
            raw = @client.generate_email_verification_token!
            AccountMailer.email_verification(@client, raw).deliver_later
          end
          AuditLogs::Record.call(
            company: current_company, user: current_user, action: "client.updated",
            auditable: @client, metadata: { name: @client.full_name, login_enabled: login_newly_enabled }
          )
          render json: { client: ClientSerializer.new(@client, company: current_company).as_json }
        else
          render json: { error: @client.errors.full_messages.first, errors: @client.errors.full_messages }, status: :unprocessable_content
        end
      end

      private

      def set_client
        @client = current_company.clients.find(params[:id])
      end

      # "Active" here means active AT THIS GYM (the membership), and every
      # contract test is restricted to this gym's contracts — a person who is
      # subscribed elsewhere must not read as subscribed here.
      def status_scope(scope, status)
        case status
        when "active" then scope.where(memberships: { active: true })
        when "inactive" then scope.where(memberships: { active: false })
        when "contract_active" then scope.where(id: client_ids_with_period(current_company.contract_periods.merge(ContractPeriod.currently_active)))
        when "contract_expired" then scope.where(id: client_ids_with_period(expired_periods))
        when "no_contract" then scope.where.not(id: company_contracts.select(:client_id))
        else scope
        end
      end

      def company_contracts
        current_company.contracts
      end

      def expired_periods
        current_company.contract_periods.where(status: :expired)
      end

      # `periods` is always one of this company's own period scopes, so a
      # person's contracts at another gym can never match here.
      def client_ids_with_period(periods)
        company_contracts.where(id: periods.select(:contract_id)).select(:client_id)
      end

      # What each status would return for the CURRENT search — the filter rail
      # shows these next to its options, so they follow the search box and not
      # the status already picked.
      def status_counts(searched)
        STATUS_FILTERS.index_with { |status| status_scope(searched, status).count }
                      .merge("all" => searched.count)
      end

      def clients_csv(clients)
        joined = current_company.memberships.pluck(:client_id, :joined_at, :active).to_h { |id, at, on| [ id, [ at, on ] ] }
        CSV.generate do |csv|
          csv << [ "First name", "Last name", "Email", "Phone", "Active", "Joined at" ]
          clients.find_each do |c|
            at, on = joined[c.id]
            csv << [ c.first_name, c.last_name, c.email, c.phone, on, at ]
          end
        end
      end

      # "active" and the gym's notes describe the MEMBERSHIP; everything else
      # describes the person and is shared across their gyms.
      def membership_params
        client_params.slice(:notes, :active).to_h.symbolize_keys
      end

      def person_params
        client_params.except(:notes, :active)
      end

      def fill_blanks_only(client, attrs)
        attrs.to_h.reject { |key, _| client.public_send(key).present? }
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
