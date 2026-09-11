module Notifications
  # Daily: wish the owner a happy birthday for each team member (coaches, and
  # non-coach staff) whose birthdate falls today. One notification per person
  # per year.
  class ScanEmployeeBirthdaysJob < ApplicationJob
    queue_as :default

    def perform
      today = Date.current
      md = today.strftime("%m-%d")

      Coach.active.where.not(birthdate: nil).includes(:company).find_each do |coach|
        next unless coach.birthdate.strftime("%m-%d") == md

        notify(coach.company&.owner, subject: coach, name: coach.full_name, url: "/owner/team")
      end

      StaffMember.active.where(coach_id: nil).where.not(birthdate: nil).includes(:company, :user).find_each do |staff|
        next unless staff.birthdate.strftime("%m-%d") == md

        notify(staff.company&.owner, subject: staff, name: staff.full_name, url: "/owner/team/#{staff.id}")
      end
    end

    def notify(owner, subject:, name:, url:)
      return if owner.nil? || name.blank?

      Notifications::Push.call(
        recipient: owner,
        kind: "employee_birthday",
        subject: subject,
        dedup_key: "birthday:#{subject.class.name}:#{subject.id}:#{Date.current.year}",
        url: url,
        data: { name: name }
      )
    end
  end
end
