module Api
  module V1
    # The public gym directory — how a person finds a gym before they have
    # any relationship with it. Unauthenticated by design, and deliberately
    # narrow: only gyms whose owner published them, and only the profile
    # fields a gym chose to show. Nothing about members, money or staff.
    class GymsController < ApplicationController
      # GET /api/v1/gyms?q=&city=&lat=&lng=
      def index
        gyms = Company.listed.directory_search(params[:q])
        gyms = gyms.where("city ILIKE ?", "%#{params[:city].strip}%") if params[:city].present?
        gyms = nearest_first(gyms).limit(100)

        render json: { gyms: gyms.map { |g| GymSerializer.new(g).as_json } }
      end

      # GET /api/v1/gyms/:id — the gym's page, with what it offers.
      def show
        gym = Company.listed.find_by(id: params[:id]) || Company.listed.find_by(slug: params[:id])
        return render json: { error: "Gym not found" }, status: :not_found if gym.nil?

        render json: { gym: GymSerializer.new(gym, detailed: true).as_json }
      end

      private

      # With coordinates from the browser, the closest gym comes first. A gym
      # whose owner never set its coordinates still appears — after the located
      # ones and with no distance — rather than disappearing from the directory
      # because of a field they left empty.
      def nearest_first(scope)
        lat = Float(params[:lat], exception: false)
        lng = Float(params[:lng], exception: false)
        return scope.order(:name) unless lat && lng && lat.abs <= 90 && lng.abs <= 180

        scope.select("companies.*, #{haversine_km(lat, lng)} AS distance_km")
             .order(Arel.sql("distance_km ASC NULLS LAST"), :name)
      end

      # Great-circle distance in kilometres.
      #
      # Two things this has to get right:
      #  - the CASE is not belt and braces: Postgres's greatest()/least()
      #    IGNORE nulls, so a gym with no coordinates would come out of the
      #    clamp as -1 and land 20 015 km away — the far side of the planet —
      #    instead of having no distance at all.
      #  - the clamp itself is there because floating point can push the
      #    cosine a hair past 1 for a point compared with itself, and acos
      #    would then return NaN.
      def haversine_km(lat, lng)
        ActiveRecord::Base.sanitize_sql_array([
          "(CASE WHEN companies.latitude IS NULL OR companies.longitude IS NULL THEN NULL ELSE " \
          "6371 * acos(least(1, greatest(-1, " \
          "cos(radians(?)) * cos(radians(companies.latitude)) * cos(radians(companies.longitude) - radians(?)) + " \
          "sin(radians(?)) * sin(radians(companies.latitude))))) END)",
          lat, lng, lat
        ])
      end
    end
  end
end
