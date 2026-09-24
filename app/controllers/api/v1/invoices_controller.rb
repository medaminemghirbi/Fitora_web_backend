module Api
  module V1
    # The gym's own invoices: the record that it paid, and the PDF it keeps.
    class InvoicesController < BaseController
      before_action :require_company!
      before_action :require_admin!
      before_action :set_invoice, only: [ :show ]

      # GET /api/v1/invoices
      def index
        render json: {
          invoices: current_company.invoices.newest_first.map { |i| InvoiceSerializer.new(i).as_json }
        }
      end

      # GET /api/v1/invoices/:id — the PDF.
      def show
        pdf = Receipts::SubscriptionInvoicePdf.call(invoice: @invoice)

        send_data pdf,
                  filename: "#{@invoice.number}.pdf",
                  type: "application/pdf",
                  disposition: "attachment"
      end

      private

      def set_invoice
        @invoice = current_company.invoices.find(params[:id])
      end
    end
  end
end
