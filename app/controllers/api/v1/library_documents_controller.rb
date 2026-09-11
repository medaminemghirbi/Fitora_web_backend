module Api
  module V1
    class LibraryDocumentsController < BaseController
      before_action :require_company!
      before_action -> { require_capability!(:company_library) }
      before_action :set_document, only: [ :show, :update, :destroy, :file ]

      # GET /api/v1/library_documents?folder_id=&status=&page=
      # status: active | inactive | expiring_soon
      def index
        documents = filtered_scope.order(title: :asc)

        render json: {
          documents: paginate(documents).map { |d| LibraryDocumentSerializer.new(d).as_json },
          meta: pagination_meta(documents)
        }
      end

      # GET /api/v1/library_documents/:id
      def show
        render json: { document: LibraryDocumentSerializer.new(@document).as_json }
      end

      # POST /api/v1/library_documents (multipart/form-data — :file is an upload)
      def create
        document = current_company.library_documents.new(document_params.merge(created_by: current_user))

        if document.save
          render json: { document: LibraryDocumentSerializer.new(document).as_json }, status: :created
        else
          render json: { error: document.errors.full_messages.first, errors: document.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/library_documents/:id
      def update
        if @document.update(document_params)
          render json: { document: LibraryDocumentSerializer.new(@document).as_json }
        else
          render json: { error: @document.errors.full_messages.first, errors: @document.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/library_documents/:id
      def destroy
        @document.destroy
        head :no_content
      end

      # GET /api/v1/library_documents/:id/file — streamed through the same
      # capability check as everything else here, instead of Active
      # Storage's public signed blob URLs (these can be sensitive business
      # documents, so "anyone with the link" isn't the right access model).
      def file
        send_data @document.file.download,
                   filename: @document.file.filename.to_s,
                   type: @document.file.content_type,
                   disposition: "inline"
      end

      private

      def set_document
        @document = current_company.library_documents.find(params[:id])
      end

      def filtered_scope
        scope = current_company.library_documents
        scope = scope.where(folder_id: params[:folder_id]) if params[:folder_id].present?
        if params[:q].present?
          t = "%#{params[:q].strip}%"
          scope = scope.where("title ILIKE :t OR reference_number ILIKE :t", t: t)
        end

        case params[:status]
        when "active" then scope.active
        when "inactive" then scope.where(active: false)
        when "expiring_soon" then scope.expiring_soon
        else scope
        end
      end

      def document_params
        params.require(:library_document).permit(:title, :folder_id, :reference_number, :issued_on, :expires_on, :notes, :active, :file)
      end
    end
  end
end
