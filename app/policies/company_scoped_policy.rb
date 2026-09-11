# Base policy for records that hang off an Company (directly or through a
# belongs_to chain). Only the owner of that company may manage them.
class CompanyScopedPolicy < ApplicationPolicy
  def index?
    user.owner?
  end

  def show?
    owns?
  end

  def create?
    user.owner?
  end

  def update?
    owns?
  end

  def destroy?
    owns?
  end

  private

  def owns?
    user.owner? && record_company_id == user.company&.id
  end

  def record_company_id
    raise NotImplementedError
  end
end
