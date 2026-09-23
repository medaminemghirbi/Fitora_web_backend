module Api
  module V1
    class ClientsController < BaseController
      before_action :require_company!
      before_action -> { require_capability!(:clients) }
      before_action :set_client, only: [ :show, :update ]

      STATUS_FILTERS = %w[active inactive contract_active contract_expired no_contract].freeze

      # Sort key → the columns it orders on. Anything else falls back to name.
      SORTS = {
        "name" => %w[clients.first_name clients.last_name],
        "joined" => %w[memberships.joined_at],
        "created" => %w[clients.created_at]
      }.freeze

      # Raised to unwind #create's transaction when the subscription half
      # fails: Contracts::Create reports a refused sale by returning, not by
      # raising, and the member must not survive it.
      Enrolment = Class.new(StandardError)

      # GET /api/v1/clients?search=&status=&page=
      # status: active | inactive | contract_active | contract_expired | no_contract
      #
      # Beyond the search box, the list narrows on the plan someone holds, the
      # activity it covers, their gender and when they joined, and it orders on
      # a whitelisted column. Everything here is optional and composes: the
      # counts are computed AFTER the narrowing, so the status pills say how
      # many rows each status would return for the filters already set.
      def index
        narrowed = narrow(current_company.clients.search(params[:search]))
        clients = status_scope(narrowed, params[:status]).order(Arel.sql(order_clause))

        if params[:format] == "csv"
          send_data clients_csv(clients), filename: "clients-#{Date.current}.csv"
        else
          page = paginate(clients).to_a
          visits = last_visits_for(page)

          render json: {
            clients: page.map { |c|
              ClientSerializer.new(c, company: current_company, last_visit_at: visits[c.id]).as_json
            },
            meta: pagination_meta(clients),
            counts: status_counts(narrowed)
          }
        end
      end

      # When each member last turned up, for the whole page in one query.
      # Asking per member would be twenty aggregates for twenty rows — the
      # kind of N+1 that only shows up once a gym has real traffic.
      def last_visits_for(page)
        return {} if page.empty?

        Booking.confirmed
               .joins(:session)
               .where(client_id: page.map(&:id), sessions: { company_id: current_company.id })
               .group(:client_id)
               .maximum("sessions.starts_at")
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
      #
      # An optional `subscription` sells them a plan in the same breath, and
      # an optional collect_payment inside it takes the money — which is what
      # actually happens at a front desk. All three land in one transaction:
      # a member who exists but has no subscription because the plan had no
      # price for that activity is exactly the mess this avoids.
      def create
        return render_forbidden if subscription_params.present? && !capability?(:contracts)

        existing = Client.find_by_email(client_params[:email])
        client = existing || Client.new
        client.assign_attributes(existing ? fill_blanks_only(client, person_params) : person_params)
        contract = nil
        payment = nil

        ActiveRecord::Base.transaction do
          client.save!
          membership = client.join!(current_company)
          membership.update!(membership_params) if membership_params.any?

          if subscription_params.present?
            result = sell_subscription(client)
            raise Enrolment, result.error unless result.success?

            contract = result.contract
            payment = result.payment
          end
        end

        AuditLogs::Record.call(
          company: current_company, user: current_user,
          action: existing ? "client.joined" : "client.created",
          auditable: client, metadata: { name: client.full_name }
        )
        render json: {
          client: ClientSerializer.new(client, company: current_company).as_json,
          contract: contract && ContractSerializer.new(contract).as_json,
          payment: payment && PaymentSerializer.new(payment).as_json
        }, status: :created
      rescue Enrolment => e
        render json: { error: e.message, errors: [ e.message ] }, status: :unprocessable_content
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.record.errors.full_messages.first, errors: e.record.errors.full_messages }, status: :unprocessable_content
      end

      # PATCH /api/v1/clients/:id
      def update
        # Setting a password is what turns the member's app on for them, so
        # it is worth recording separately from an ordinary edit.
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

      # The advanced filters, each a no-op when its parameter is absent.
      def narrow(scope)
        scope = scope.where(id: plan_holders.select(:client_id)) if params[:contract_type_id].present?
        scope = scope.where(id: activity_holders.select(:client_id)) if params[:activity_id].present?
        scope = scope.where(gender: params[:gender]) if params[:gender].present?

        from = parse_date(params[:joined_from])
        to = parse_date(params[:joined_to])
        scope = scope.where(memberships: { joined_at: from.beginning_of_day.. }) if from
        scope = scope.where(memberships: { joined_at: ..to.end_of_day }) if to
        scope
      end

      def plan_holders
        company_contracts.where(contract_type_id: params[:contract_type_id])
      end

      # An all-access contract (activity_id NULL) covers every activity its
      # plan is priced for, so filtering on an activity has to find those too
      # — see Contract#covers_activity?, which is the same rule.
      def activity_holders
        id = params[:activity_id]
        all_access_plans = current_company.contract_types
                                          .joins(:contract_type_activities)
                                          .where(contract_type_activities: { activity_id: id })

        company_contracts.where(activity_id: id)
                         .or(company_contracts.where(activity_id: nil, contract_type_id: all_access_plans))
      end

      def parse_date(value)
        Date.parse(value.to_s)
      rescue Date::Error, TypeError
        nil
      end

      # A whitelist, because both halves come off a query string. "name" is two
      # columns, so the direction has to be spelled onto each of them.
      def order_clause
        direction = params[:direction] == "desc" ? "DESC" : "ASC"
        columns = SORTS.fetch(params[:sort], SORTS.fetch("name"))
        columns.map { |column| "#{column} #{direction}" }.join(", ")
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
      # The capability check for this half lives at the top of #create:
      # selling a plan is a different permission from recording a member, and
      # it has to be refused before anything is written.
      def sell_subscription(client)
        sub = subscription_params

        plan = current_company.contract_types.find_by(id: sub[:contract_type_id])
        raise Enrolment, "Plan not found" if plan.nil?

        activity = current_company.activities.find_by(id: sub[:activity_id])
        raise Enrolment, "Activity not found" if activity.nil?

        Contracts::Create.call(
          client: client, contract_type: plan, activity: activity, created_by: current_user,
          starts_on: sub[:starts_on].presence&.to_date || Date.current,
          discount: sub[:discount].presence || 0,
          collect_payment: sub[:collect_payment],
          payment_method: sub[:payment_method],
          payment_notes: sub[:payment_notes]
        )
      end

      def subscription_params
        return {} if params[:subscription].blank?

        params.require(:subscription).permit(
          :contract_type_id, :activity_id, :starts_on, :discount,
          :collect_payment, :payment_method, :payment_notes
        )
      end

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
