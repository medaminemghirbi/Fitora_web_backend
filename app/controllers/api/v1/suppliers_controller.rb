module Api
  module V1
    class SuppliersController < BaseController
      before_action :require_company!
      before_action -> { require_capability!(:suppliers) }
      before_action :set_supplier, only: [ :show, :update, :destroy ]

      # GET /api/v1/suppliers?search=
      def index
        suppliers = current_company.suppliers.search(params[:search]).order(:name)
        render json: { suppliers: suppliers.map { |s| SupplierSerializer.new(s).as_json } }
      end

      # GET /api/v1/suppliers/:id
      def show
        render json: { supplier: SupplierSerializer.new(@supplier).as_json }
      end

      # POST /api/v1/suppliers (multipart/form-data — :photo is an optional upload)
      def create
        supplier = current_company.suppliers.new(supplier_params)

        if supplier.save
          render json: { supplier: SupplierSerializer.new(supplier).as_json }, status: :created
        else
          render json: { error: supplier.errors.full_messages.first, errors: supplier.errors.to_hash }, status: :unprocessable_content
        end
      end

      # PATCH /api/v1/suppliers/:id
      def update
        if @supplier.update(supplier_params)
          render json: { supplier: SupplierSerializer.new(@supplier).as_json }
        else
          render json: { error: @supplier.errors.full_messages.first, errors: @supplier.errors.to_hash }, status: :unprocessable_content
        end
      end

      # DELETE /api/v1/suppliers/:id — soft deactivate, same convention as Coach.
      def destroy
        @supplier.update!(active: false)
        render json: { supplier: SupplierSerializer.new(@supplier).as_json }
      end

      private

      def set_supplier
        @supplier = current_company.suppliers.find(params[:id])
      end

      def supplier_params
        params.require(:supplier).permit(:name, :category, :contact_name, :phone, :email, :address, :notes, :active, :photo)
      end
    end
  end
end
