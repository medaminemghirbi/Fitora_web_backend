module Api
  module V1
    module Admin
      class CompaniesController < BaseController
        before_action :require_admin!
        before_action :set_company, only: [ :show, :update_subscription, :update_settings, :update_debt, :update_company_limit, :impersonate ]

        # GET /api/v1/admin/companies
        def index
          companies = Company.includes(:owner, :subscription).search(params[:q]).order(:name)

          render json: {
            companies: paginate(companies).map { |o| AdminCompanySerializer.new(o).as_json },
            meta: pagination_meta(companies)
          }
        end

        # GET /api/v1/admin/companies/activation_requests — the gyms asking
        # to carry on past their trial.
        #
        # Lives beside the company list rather than inside it because this is
        # an inbox, not a directory: it answers "who is waiting on me", and
        # it empties as they are answered.
        def activation_requests
          subscriptions = Subscription.awaiting_activation.includes(company: :owner)
          companies = subscriptions.filter_map(&:company)

          render json: { companies: companies.map { |c| AdminCompanySerializer.new(c).as_json } }
        end

        # GET /api/v1/admin/companies/:id
        def show
          render json: {
            company: AdminCompanySerializer.new(@company).as_json,
            currency_options: CurrencyCatalog.options,
            locale_options: Company::LOCALES
          }
        end

        # PATCH /api/v1/admin/companies/:id/subscription — direct admin
        # override of a company's access status. No plans, no billing: the
        # owner is invoiced/paid outside the app, this just grants or
        # revokes access by hand.
        def update_subscription
          subscription = @company.subscription || @company.build_subscription(starts_at: Time.current)
          previous_status = subscription.status

          attrs = {
            status: params[:status] || subscription.status,
            # Granting ongoing access clears the free-trial deadline by
            # default so the company is unlocked. Pass expires_at explicitly
            # to set a new one instead (e.g. a renewal date).
            expires_at: params[:expires_at].presence
          }
          if params.key?(:billing_period)
            # Setting a billing period activates a real (paid) subscription
            # — it also resolves any pending activation request from the owner.
            attrs[:billing_period] = params[:billing_period].presence
            attrs[:upgrade_requested_at] = nil
            attrs[:upgrade_requested_period] = nil
          end

          if subscription.update(attrs)
            AuditLogs::Record.call(
              company: @company, user: current_user, action: "subscription.status_overridden",
              auditable: subscription, metadata: { from: previous_status, to: subscription.status, billing_period: subscription.billing_period }
            )
            render json: { company: AdminCompanySerializer.new(@company.reload).as_json }
          else
            render json: { error: subscription.errors.full_messages.first, errors: subscription.errors.full_messages }, status: :unprocessable_content
          end
        end

        # PATCH /api/v1/admin/companies/:id/settings — tenant-wide display
        # settings a Fitora admin controls on the company's behalf: the app
        # language and the billing/display currency. { company: { currency:,
        # locale: } }.
        def update_settings
          if @company.update(company_settings_params)
            AuditLogs::Record.call(
              company: @company, user: current_user, action: "admin.settings_updated",
              auditable: @company, metadata: { currency: @company.currency, locale: @company.locale }
            )
            render json: { company: AdminCompanySerializer.new(@company).as_json }
          else
            render json: { error: @company.errors.full_messages.first, errors: @company.errors.full_messages }, status: :unprocessable_content
          end
        end

        # PATCH /api/v1/admin/companies/:id/debt — the running balance the
        # company owes Fitora off-app. Purely informational on this side too
        # (no invoicing), just a number an admin keeps up to date so the
        # owner sees it on their modules page.
        def update_debt
          previous = @company.debt_cents

          if @company.update(debt_cents: params[:debt_cents])
            AuditLogs::Record.call(
              company: @company, user: current_user, action: "admin.debt_updated",
              auditable: @company, metadata: { from: previous, to: @company.debt_cents }
            )
            render json: { company: AdminCompanySerializer.new(@company).as_json }
          else
            render json: { error: @company.errors.full_messages.first, errors: @company.errors.full_messages }, status: :unprocessable_content
          end
        end

        # PATCH /api/v1/admin/companies/:id/company_limit — { company_limit }
        # (1, 3, or blank/null for unlimited). Reached via any one of the
        # owner's companies in the admin console, but it governs the OWNER,
        # not this company — every company they run shares the same tier
        # and its price (Company#monthly_subscription_cents).
        def update_company_limit
          owner = @company.owner
          previous = owner.company_limit

          if owner.update(company_limit: params[:company_limit].presence)
            AuditLogs::Record.call(
              company: @company, user: current_user, action: "owner.company_limit_changed",
              auditable: owner, metadata: { from: previous, to: owner.company_limit }
            )
            render json: { company: AdminCompanySerializer.new(@company.reload).as_json }
          else
            render json: { error: owner.errors.full_messages.first, errors: owner.errors.full_messages }, status: :unprocessable_content
          end
        end

        # POST /api/v1/admin/companies/:id/impersonate — issues a real
        # login session for the company's owner, marked with this
        # admin's id so it's traceable, and reuses the entire owner-facing
        # app as-is instead of duplicating every page for admin use.
        def impersonate
          owner = @company.owner
          return render json: { error: "This company has no owner account" }, status: :unprocessable_content if owner.nil?

          AuditLogs::Record.call(
            company: @company, user: owner, action: "admin.impersonation_started",
            auditable: @company, metadata: { admin_id: current_user.id, admin_email: current_user.email }
          )

          render json: { token: JwtService.encode(owner.id, impersonator_id: current_user.id), user: UserSerializer.new(owner).as_json }
        end

        private

        def set_company
          @company = Company.find(params[:id])
        end

        def company_settings_params
          params.require(:company).permit(:currency, :locale)
        end
      end
    end
  end
end
