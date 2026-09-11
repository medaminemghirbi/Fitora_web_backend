module Api
  module V1
    class PairingController < ApplicationController
      # GET /api/v1/pairing/:mobile_auth_key — unauthenticated by design:
      # this is how the mobile app resolves which company it belongs to
      # (scanned from the QR in Settings > Application mobile) before any
      # login exists yet. Only ever returns branding — the same
      # public-within-the-app subset BrandingController exposes to any
      # authenticated staff member — never anything else about the company.
      def show
        company = Company.find_by(mobile_auth_key: params[:mobile_auth_key].to_s.downcase.strip)
        return render json: { error: "Invalid pairing key" }, status: :not_found if company.nil?

        render json: { branding: CompanyBrandingSerializer.new(company).as_json }
      end
    end
  end
end
