module Coaches
  class SetLogin
    Result = Struct.new(:success?, :staff_member, :error, keyword_init: true)

    def self.call(coach:, email:, password:)
      new(coach: coach, email: email, password: password).call
    end

    def initialize(coach:, email:, password:)
      @coach = coach
      @email = email
      @password = password
    end

    # A Coach may already have a login (staff_member present, set up by the
    # owner earlier or by an earlier call here) — in that case this just
    # resets the linked User's email/password. Otherwise it provisions a
    # fresh staff account (role: coach) and links it to this Coach.
    def call
      ActiveRecord::Base.transaction do
        staff_member = coach.staff_member || create_staff_member!
        staff_member.user.update!(email: email, password: password)
        Result.new(success?: true, staff_member: staff_member.reload, error: nil)
      end
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, staff_member: nil, error: e.record.errors.full_messages.first)
    end

    private

    attr_reader :coach, :email, :password

    def create_staff_member!
      user = User.create!(
        first_name: coach.first_name, last_name: coach.last_name,
        email: email, password: password, role: :staff, locale: "fr"
      )
      staff_member = coach.company.staff_members.create!(user: user, assigned_role: coach_role, coach: coach)
      staff_member
    end

    # The company's built-in coach role. Seeded with every company, but a
    # gym created before the role table existed may not have it — seed it
    # rather than fail provisioning a login over it.
    def coach_role
      coach.company.roles.find_by(key: "coach") || begin
        Role.seed_defaults_for(coach.company)
        coach.company.roles.find_by!(key: "coach")
      end
    end
  end
end
