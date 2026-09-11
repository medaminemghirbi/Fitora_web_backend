module Api
  module V1
    class BrandingController < BaseController
      before_action :require_company!

      # GET /api/v1/branding — any authenticated company member (owner or
      # staff) can read this; full company settings stay behind
      # CompaniesController's require_owner!.
      def show
        render json: { branding: CompanyBrandingSerializer.new(current_company).as_json }
      end
    end
  end
end
