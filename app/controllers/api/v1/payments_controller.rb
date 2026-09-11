module Api
  module V1
    class PaymentsController < BaseController
      before_action :require_company!
      before_action -> { require_capability!(:payments) }
      before_action :set_payment, only: [ :show, :refund ]

      # GET /api/v1/payments?status=&payment_method=&date=
      def index
        scope = current_company.payments.includes(:client)
        scope = scope.where(status: params[:status]) if params[:status].present?
        scope = scope.where(payment_method: params[:payment_method]) if params[:payment_method].present?
        scope = scope.where("created_at >= ?", Date.parse(params[:date]).beginning_of_day) if params[:date].present?
        if params[:q].present?
          t = "%#{params[:q].strip}%"
          scope = scope.joins(:client).where("clients.first_name ILIKE :t OR clients.last_name ILIKE :t", t: t)
        end
        scope = scope.recent

        if params[:format] == "csv"
          send_data payments_csv(scope), filename: "payments-#{Date.current}.csv"
        else
          render json: {
            payments: paginate(scope).map { |p| PaymentSerializer.new(p).as_json },
            meta: pagination_meta(scope)
          }
        end
      end

      # GET /api/v1/payments/:id
      def show
        render json: { payment: PaymentSerializer.new(@payment).as_json }
      end

      # POST /api/v1/payments — staff manually records a payment against a
      # client's contract or booking
      def create
        client = current_company.clients.find_by(id: params[:client_id])
        return render json: { error: "Client not found" }, status: :not_found if client.nil?

        result = Payments::Record.call(
          client: client, company: current_company, created_by: current_user,
          amount: params[:amount], payment_method: params[:payment_method], notes: params[:notes],
          contract_period: find_payable(client.contract_periods, params[:contract_period_id]),
          booking: find_payable(client.bookings, params[:booking_id])
        )

        if result.success?
          render json: { payment: PaymentSerializer.new(result.payment).as_json }, status: :created
        else
          render json: { error: result.error }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/payments/:id/refund
      def refund
        result = Payments::Refund.call(payment: @payment)

        if result.success?
          render json: { payment: PaymentSerializer.new(@payment.reload).as_json }
        else
          render json: { error: result.error }, status: :unprocessable_entity
        end
      end

      private

      def find_payable(scope, id)
        return nil if id.blank?

        scope.find_by(id: id)
      end

      def set_payment
        @payment = current_company.payments.find_by(id: params[:id])
        render_not_found if @payment.nil?
      end

      def payments_csv(scope)
        CSV.generate do |csv|
          csv << [ "Client", "Amount", "Currency", "Method", "Status", "Paid at" ]
          scope.includes(:client).find_each do |p|
            csv << [ p.client.full_name, p.amount, p.currency, p.payment_method, p.status, p.paid_at ]
          end
        end
      end
    end
  end
end
