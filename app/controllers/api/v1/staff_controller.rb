module Api
  module V1
    class StaffController < BaseController
      before_action :require_company!
      before_action :require_staff_manager!
      before_action :set_staff_member, only: [ :show, :update ]

      # GET /api/v1/staff
      def index
        staff = current_company.staff_members.includes(:user, :coach).order(:role)
        render json: { staff: staff.map { |s| StaffMemberSerializer.new(s).as_json } }
      end

      # GET /api/v1/staff/:id
      def show
        render json: { staff_member: StaffMemberSerializer.new(@staff_member).as_json }
      end

      # POST /api/v1/staff — auto-assigned to the company's one location
      def create
        user = User.new(user_params.merge(role: :staff, locale: user_params[:locale].presence || "fr"))
        staff_member = nil

        ActiveRecord::Base.transaction do
          user.save!
          staff_member = current_company.staff_members.create!(
            user: user,
            coach_id: staff_params[:coach_id],
            birthdate: staff_params[:birthdate],
            **role_assignment
          )
          staff_member.staff_member_locations.create!(location: current_company.location)
        end

        AuditLogs::Record.call(
          company: current_company, user: current_user, action: "staff.created",
          auditable: staff_member, metadata: { role: staff_member.role_key, staff_email: user.email }
        )

        raw = user.generate_email_verification_token!
        AccountMailer.email_verification(user, raw).deliver_later

        render json: { staff_member: StaffMemberSerializer.new(staff_member).as_json }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.record.errors.full_messages.first, errors: e.record.errors.full_messages }, status: :unprocessable_content
      end

      # PATCH /api/v1/staff/:id
      def update
        previous_key = @staff_member.role_key
        attrs = { active: staff_params[:active], birthdate: staff_params[:birthdate], coach_id: staff_params[:coach_id] }
                  .compact.merge(role_assignment)

        if @staff_member.update(attrs)
          if previous_key != @staff_member.reload.role_key
            AuditLogs::Record.call(
              company: current_company, user: current_user, action: "staff.role_changed",
              auditable: @staff_member, metadata: { from: previous_key, to: @staff_member.role_key }
            )
          end

          render json: { staff_member: StaffMemberSerializer.new(@staff_member).as_json }
        else
          render json: { error: @staff_member.errors.full_messages.first, errors: @staff_member.errors.full_messages }, status: :unprocessable_content
        end
      end

      private

      # Staff management is owner-only now — no in-company staff role has full
      # access anymore, so there's no "staff-admin" exception to make here.
      def require_staff_manager!
        render_forbidden unless current_user.owner?
      end

      def set_staff_member
        @staff_member = current_company.staff_members.find(params[:id])
      end

      def user_params
        params.require(:staff_member).permit(:first_name, :last_name, :email, :phone, :password, :locale)
      end

      def staff_params
        params.require(:staff_member).permit(:role, :role_id, :active, :coach_id, :birthdate)
      end

      # Translate an incoming assignment into { role: <kind>, assigned_role: }.
      # `role_id` (roles editor) wins; the legacy `role` enum string is the
      # fallback (its enum-sync fills assigned_role for a built-in). Returns
      # {} when neither is present so an unrelated update leaves the role be.
      def role_assignment
        if staff_params[:role_id].present?
          role = current_company.roles.find(staff_params[:role_id])
          { role: (role.key == "coach" ? :coach : :receptionist), assigned_role: role }
        elsif staff_params[:role].present?
          { role: staff_params[:role], assigned_role: nil }
        else
          {}
        end
      end
    end
  end
end
