module Api
  module V1
    module Superadmin
      class CompaniesController < BaseController
        before_action :require_superadmin!
        before_action :set_company, only: [ :show, :update_subscription, :update_settings, :update_company_limit, :impersonate, :invoices, :create_invoice, :destroy_invoice ]

        # GET /api/v1/superadmin/companies?q=&closed=1
        #
        # `closed` narrows to the gyms whose access is shut. The count comes
        # back either way, so the list says how many without a screen of its
        # own — nobody should have to open a gym's page to find out.
        def index
          companies = Company.includes(:admin, :subscription).search(params[:q])
          closed = companies.joins(:subscription).where(subscriptions: { active: false })

          only_closed = ActiveModel::Type::Boolean.new.cast(params[:closed])
          scope = (only_closed ? closed : companies).reorder(:name)

          render json: {
            companies: paginate(scope).map { |o| SuperadminCompanySerializer.new(o).as_json },
            meta: pagination_meta(scope),
            closed_count: closed.count
          }
        end

        # GET /api/v1/superadmin/companies/:id
        def show
          render json: {
            company: SuperadminCompanySerializer.new(@company).as_json,
            currency_options: CurrencyCatalog.options,
            locale_options: Company::LOCALES
          }
        end

        # PATCH /api/v1/superadmin/companies/:id/subscription — access is a
        # boolean, so this sets two things: whether the door is open, and
        # whether an invoice covers one month or twelve. Neither ends a
        # trial: only an invoice does (#create_invoice).
        def update_subscription
          subscription = @company.subscription || @company.build_subscription

          attrs = {}
          attrs[:active] = ActiveModel::Type::Boolean.new.cast(params[:active]) if params.key?(:active)
          attrs[:billing_period] = params[:billing_period].presence if params.key?(:billing_period)
          was_active = subscription.active

          if subscription.update(attrs)
            # Only a change of access is an access event. Picking what the
            # next invoice covers used to be logged as "access restored",
            # which is what the admin's feed then told them.
            action =
              if subscription.active == was_active then "subscription.billing_period_changed"
              elsif subscription.active? then "subscription.access_restored"
              else "subscription.access_suspended"
              end
            AuditLogs::Record.call(
              company: @company, user: current_user, action: action,
              auditable: subscription, metadata: { from: was_active, to: subscription.active, billing_period: subscription.billing_period }
            )
            render json: { company: SuperadminCompanySerializer.new(@company.reload).as_json }
          else
            render_errors(subscription)
          end
        end

        # PATCH /api/v1/superadmin/companies/:id/settings — tenant-wide display
        # settings a Gymly superadmin controls on the company's behalf: the app
        # language and the billing/display currency. { company: { currency:,
        # locale: } }.
        def update_settings
          if @company.update(company_settings_params)
            AuditLogs::Record.call(
              company: @company, user: current_user, action: "superadmin.settings_updated",
              auditable: @company, metadata: { currency: @company.currency, locale: @company.locale }
            )
            render json: { company: SuperadminCompanySerializer.new(@company).as_json }
          else
            render_errors(@company)
          end
        end

        # PATCH /api/v1/superadmin/companies/:id/debt — the running balance the
        # company owes Gymly off-app. Purely informational on this side too
        # (no invoicing), just a number a superadmin keeps up to date so the
        # admin sees it on their modules page.
        # PATCH /api/v1/superadmin/companies/:id/company_limit — { company_limit }
        # (1, 3, or blank/null for unlimited). Reached via any one of the
        # admin's companies in the superadmin console, but it governs the ADMIN,
        # not this company — every company they run shares the same tier
        # and its price (Company#monthly_subscription_cents).
        def update_company_limit
          admin = @company.admin
          previous = admin.company_limit

          if admin.update(company_limit: params[:company_limit].presence)
            AuditLogs::Record.call(
              company: @company, user: current_user, action: "admin.company_limit_changed",
              auditable: admin, metadata: { from: previous, to: admin.company_limit }
            )
            render json: { company: SuperadminCompanySerializer.new(@company.reload).as_json }
          else
            render_errors(admin)
          end
        end

        # POST /api/v1/superadmin/companies/:id/impersonate — issues a real
        # login session for the company's admin, marked with this
        # superadmin's id so it's traceable, and reuses the entire admin-facing
        # app as-is instead of duplicating every page for superadmin use.
        def impersonate
          admin = @company.admin
          return render json: { error: "This company has no admin account" }, status: :unprocessable_content if admin.nil?

          AuditLogs::Record.call(
            company: @company, user: admin, action: "superadmin.impersonation_started",
            auditable: @company, metadata: { superadmin_id: current_user.id, superadmin_email: current_user.email }
          )

          render json: { token: JwtService.for_user(admin, impersonator: current_user), user: UserSerializer.new(admin).as_json }
        end

        # GET /api/v1/superadmin/companies/:id/invoices
        def invoices
          render json: {
            invoices: @company.invoices.newest_first.map { |i| InvoiceSerializer.new(i).as_json }
          }
        end

        # POST /api/v1/superadmin/companies/:id/invoices — the money arrived.
        #
        # Issues one invoice for the next period the gym has not paid for
        # and opens access again. Payment happens off-app, so this is the
        # only record that it happened at all.
        def create_invoice
          result = Invoices::Issue.call(company: @company, issued_by: current_user, notes: params[:notes].presence)

          if result.success?
            AuditLogs::Record.call(
              company: @company, user: current_user, action: "subscription.invoice_issued",
              auditable: result.invoice,
              metadata: { number: result.invoice.number, period_end: result.invoice.period_end, amount_cents: result.invoice.amount_cents }
            )
            Notifications::Push.call(
              recipient: @company.admin, kind: "invoice_issued",
              data: { number: result.invoice.number, amount: result.invoice.amount, currency: result.invoice.currency },
              url: "/admin/subscription", dedup_key: "invoice-#{result.invoice.id}"
            )
            render json: {
              invoice: InvoiceSerializer.new(result.invoice).as_json,
              company: SuperadminCompanySerializer.new(@company.reload).as_json
            }, status: :created
          else
            render json: { error: result.error }, status: :unprocessable_content
          end
        end

        # DELETE /api/v1/superadmin/companies/:id/invoices/:invoice_id — an
        # invoice issued in error. Deleting it takes the coverage back with
        # it; the sweep closes access again if that leaves the gym uncovered.
        def destroy_invoice
          invoice = @company.invoices.find(params[:invoice_id])
          number = invoice.number
          invoice.destroy!

          AuditLogs::Record.call(
            company: @company, user: current_user, action: "subscription.invoice_voided",
            auditable: @company, metadata: { number: number }
          )
          render json: { company: SuperadminCompanySerializer.new(@company.reload).as_json }
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
