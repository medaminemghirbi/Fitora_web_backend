module Api
  module V1
    # The "Contact" tab on the modules marketplace page — a problem report
    # with optional file/video attachments, reviewed by a Fitora admin from
    # a cross-company inbox (Api::V1::Admin::SupportTicketsController).
    class SupportTicketsController < BaseController
      before_action :require_owner!
      before_action :set_ticket, only: [ :attachment ]

      # GET /api/v1/support_tickets
      def index
        tickets = current_company.support_tickets.recent
        render json: { support_tickets: tickets.map { |t| SupportTicketSerializer.new(t).as_json } }
      end

      # POST /api/v1/support_tickets (multipart/form-data — attachments[] are uploads)
      def create
        ticket = current_company.support_tickets.new(
          subject: params[:subject], message: params[:message], created_by: current_user
        )
        ticket.attachments.attach(params[:attachments]) if params[:attachments].present?

        if ticket.save
          AuditLogs::Record.call(
            company: current_company, user: current_user, action: "support_ticket.created",
            auditable: ticket, metadata: { subject: ticket.subject }
          )
          render json: { support_ticket: SupportTicketSerializer.new(ticket).as_json }, status: :created
        else
          render json: { error: ticket.errors.full_messages.first, errors: ticket.errors.full_messages }, status: :unprocessable_content
        end
      end

      # GET /api/v1/support_tickets/:id/attachments/:attachment_id — streamed
      # rather than a public Active Storage URL, so access still goes through
      # the tenant/permission check above instead of a guessable public link.
      def attachment
        file = @ticket.attachments.find(params[:attachment_id])
        send_data file.download, filename: file.filename.to_s, type: file.content_type, disposition: "inline"
      end

      private

      def set_ticket
        @ticket = current_company.support_tickets.find(params[:id])
      end
    end
  end
end
