module Dashboard
  class Revenue
    def self.call(company:)
      new(company: company).call
    end

    def initialize(company:)
      @company = company
    end

    def call
      {
        today: paid_scope.where(paid_at: Time.current.all_day).sum(:amount),
        this_week: paid_scope.where(paid_at: Time.current.all_week).sum(:amount),
        this_month: paid_scope.where(paid_at: Time.current.all_month).sum(:amount),
        by_day: grouped_by_day
      }
    end

    private

    attr_reader :company

    def paid_scope
      company.payments.paid
    end

    def grouped_by_day
      paid_scope.where(paid_at: 13.days.ago.beginning_of_day..Time.current)
                .group("DATE(paid_at)")
                .order("DATE(paid_at)")
                .sum(:amount)
                .map { |date, total| { date: date, total: total } }
    end
  end
end
