module Api
  module V1
    class CompaniesController < BaseController
      before_action :require_owner!
      before_action :set_owned_company, only: [ :switch ]

      # GET /api/v1/company — the owner's currently ACTIVE company (see
      # #switch). Everything else in the API (current_company) follows
      # whichever one this is.
      def show
        render json: { company: CompanySerializer.new(current_company).as_json }
      end

      # GET /api/v1/companies — every company this owner runs, for the
      # navbar switcher. Order is oldest-first (predictable, matches
      # signup order) rather than alphabetical, which would reorder itself
      # as they rename one.
      def index
        companies = current_user.companies.order(:created_at)
        render json: {
          companies: companies.map { |c| CompanySummarySerializer.new(c, active: c.id == current_user.active_company_id).as_json }
        }
      end

      # POST /api/v1/companies — a second (or third…) company under the
      # same owner login. Capped by company_limit (see User#company_limit);
      # nil means unlimited. Becomes the active company immediately.
      def create
        if current_user.company_limit_reached?
          return render json: {
            error: "company_limit_reached",
            message: "Your plan allows #{current_user.company_limit} " \
                     "#{current_user.company_limit == 1 ? 'company' : 'companies'}. Contact Fitora to upgrade."
          }, status: :unprocessable_content
        end

        company = Company.new(company_params)
        company.owner = current_user

        ActiveRecord::Base.transaction do
          company.save!

          # Built-in roles (owner/manager/receptionist/coach) — a company can
          # re-permission them or add its own from Settings.
          Role.seed_defaults_for(company)

          # 14-day free trial, full access, no plan to pick. Subscription#locked?
          # flips on once expires_at passes, unless a platform admin grants
          # ongoing access first (which clears it). See
          # Api::V1::BaseController#enforce_trial_lock! — this is entirely
          # independent per company, so one of an owner's companies being
          # locked never blocks them from creating or using another.
          company.create_subscription!(
            status: :active,
            starts_at: Time.current,
            expires_at: 14.days.from_now
          )


          current_user.update!(active_company: company)
        end

        render json: { company: CompanySerializer.new(company).as_json }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.record.errors.full_messages.first, errors: e.record.errors.full_messages }, status: :unprocessable_content
      end

      # PATCH /api/v1/company
      def update
        require_company!
        return if performed?

        # currency + locale are tenant-wide settings a Fitora admin manages
        # (Api::V1::Admin::CompaniesController#update_settings); the owner
        # only picks a currency once, at signup.
        if current_company.update(company_params.except(:currency))
          render json: { company: CompanySerializer.new(current_company).as_json }
        else
          render json: { error: current_company.errors.full_messages.first, errors: current_company.errors.full_messages }, status: :unprocessable_content
        end
      end

      # POST /api/v1/companies/:id/switch — moves the owner's active
      # session to another of their OWN companies (set_owned_company 404s
      # on anything else, same as every other tenant-scoped lookup).
      def switch
        current_user.switch_active_company!(@company)
        render json: { company: CompanySerializer.new(@company).as_json }
      end

      private

      def set_owned_company
        @company = current_user.companies.find(params[:id])
      end

      def company_params
        params.require(:company).permit(
          :name, :description, :phone, :email, :country, :city,
          :address, :latitude, :longitude, :timezone, :currency,
          :slug, :primary_color, :logo,
          :business_hours_start, :business_hours_end,
          working_days: []
        )
      end
    end
  end
end
