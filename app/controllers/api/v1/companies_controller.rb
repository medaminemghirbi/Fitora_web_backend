module Api
  module V1
    class CompaniesController < BaseController
      before_action :require_admin!
      before_action :set_owned_company, only: [ :switch ]

      # GET /api/v1/company — the admin's currently ACTIVE company (see
      # #switch). Everything else in the API (current_company) follows
      # whichever one this is.
      def show
        render json: { company: CompanySerializer.new(current_company).as_json }
      end

      # GET /api/v1/companies — every company this admin runs, for the
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
      # same admin login. Capped by company_limit (see User#company_limit);
      # nil means unlimited. Becomes the active company immediately.
      def create
        if current_user.company_limit_reached?
          return render json: {
            error: "company_limit_reached",
            message: "Your plan allows #{current_user.company_limit} " \
                     "#{current_user.company_limit == 1 ? 'company' : 'companies'}. Contact Gymly to upgrade."
          }, status: :unprocessable_content
        end

        result = Companies::Open.call(admin: current_user, attributes: company_params)
        return render_errors(result.company.errors.any? ? result.company : result.error) unless result.success?

        render json: { company: CompanySerializer.new(result.company).as_json }, status: :created
      end

      # PATCH /api/v1/company
      def update
        require_company!
        return if performed?

        # currency + locale are tenant-wide settings a Gymly superadmin manages
        # (Api::V1::Superadmin::CompaniesController#update_settings); the admin
        # only picks a currency once, at signup.
        if current_company.update(company_params.except(:currency))
          render json: { company: CompanySerializer.new(current_company).as_json }
        else
          render_errors(current_company)
        end
      end

      # POST /api/v1/companies/:id/switch — moves the admin's active
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
        permitted = params.require(:company).permit(
          :name, :description, :phone, :email, :country, :city,
          :address, :latitude, :longitude, :timezone, :currency,
          :slug, :logo,
          # Hours and branding are settings now, but the app still sends them
          # flat. Accept them where they have always been and fold them in.
          :primary_color, :business_hours_start, :business_hours_end,
          working_days: [],
          settings: [
            { features: CompanySettings::FEATURES.keys },
            { booking: CompanySettings::BOOKING.keys },
            { hours: [ :start, :end, { working_days: [] } ] },
            { branding: CompanySettings::BRANDING.keys }
          ]
        )

        fold_legacy_settings_keys(permitted)
      end

      # Moves the flat hours/branding keys into the settings patch, so the
      # model sees one shape whichever way the client sent them. An explicit
      # `settings` section wins over the flat key for the same value.
      def fold_legacy_settings_keys(permitted)
        hours = {
          start: permitted.delete(:business_hours_start),
          end: permitted.delete(:business_hours_end),
          working_days: permitted.delete(:working_days)
        }.compact
        branding = { primary_color: permitted.delete(:primary_color) }.compact

        return permitted if hours.empty? && branding.empty?

        settings = (permitted[:settings] || {}).to_h.symbolize_keys
        settings[:hours] = hours.merge((settings[:hours] || {}).to_h.symbolize_keys)
        settings[:branding] = branding.merge((settings[:branding] || {}).to_h.symbolize_keys)
        permitted[:settings] = settings
        permitted
      end
    end
  end
end
