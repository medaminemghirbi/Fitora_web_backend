class BookingPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    staff_access?
  end

  def create?
    staff_access_for_create?
  end

  def cancel?
    staff_access?
  end

  def remind?
    staff_access?
  end

  private

  # Owner always; staff need the `bookings` capability (manager, receptionist,
  # or a coach — narrowed to bookings on their own sessions only).
  def staff_access?
    return false if record.session.location.company_id != (user.company&.id || user.staff_member&.company_id)

    return true if user.owner?

    staff = user.staff_member
    return false unless staff&.active? && staff.can?(:bookings)

    staff.coach? ? record.session.coach_id == staff.coach_id : true
  end

  def staff_access_for_create?
    return true if user.owner?

    staff = user.staff_member
    staff&.active? && staff.can?(:bookings)
  end
end
