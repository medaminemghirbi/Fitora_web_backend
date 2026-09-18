module Api
  module V1
    class BrandingController < BaseController
      before_action :set_company

      # GET /api/v1/branding — any authenticated company member (owner or
      # staff) reads their own company's; full company settings stay behind
      # CompaniesController's require_owner!.
      def show
        render json: { branding: CompanyBrandingSerializer.new(@company).as_json }
      end

      private

      def set_company
        @company = current_company
        render json: { error: "No company found for this account" }, status: :unprocessable_content if @company.nil?
      end
    end
  end
end
