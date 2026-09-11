FactoryBot.define do
  factory :attendance_record do
    booking
    status { :present }
  end
end
