module Api
  module V1
    class LibraryFoldersController < BaseController
      before_action :require_company!
      before_action -> { require_capability!(:company_library) }
      before_action :set_folder, only: [ :show, :update, :destroy ]

      # GET /api/v1/library_folders
      def index
        folders = current_company.library_folders.order(:name)
        render json: { folders: folders.map { |f| LibraryFolderSerializer.new(f).as_json } }
      end

      # GET /api/v1/library_folders/:id
      def show
        render json: { folder: LibraryFolderSerializer.new(@folder).as_json }
      end

      # POST /api/v1/library_folders
      def create
        folder = current_company.library_folders.new(folder_params.merge(created_by: current_user))

        if folder.save
          render json: { folder: LibraryFolderSerializer.new(folder).as_json }, status: :created
        else
          render json: { error: folder.errors.full_messages.first, errors: folder.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/library_folders/:id
      def update
        if @folder.update(folder_params)
          render json: { folder: LibraryFolderSerializer.new(@folder).as_json }
        else
          render json: { error: @folder.errors.full_messages.first, errors: @folder.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/library_folders/:id
      def destroy
        @folder.destroy
        head :no_content
      end

      private

      def set_folder
        @folder = current_company.library_folders.find(params[:id])
      end

      def folder_params
        params.require(:library_folder).permit(:name)
      end
    end
  end
end
