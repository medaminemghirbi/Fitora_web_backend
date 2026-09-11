# Fitora seed data — minimal bootstrap only.
#
# Platform admin: admin@fitora.test / password123
#
# No demo gym, owner, staff, or clients — this used to seed a full "Fitora
# Fitness Sousse" dataset (coaches, activities, sessions, contracts,
# bookings, payments, documents…) for manual testing. That's gone: seeds.rb
# now only creates what any fresh install actually needs — the reference
# subscription price and the one account that can reach /admin. To try the
# owner side, register a real company via POST /api/v1/company (or
# /auth/register on the frontend) after seeding.

puts "Seeding the reference subscription price + platform settings..."
SubscriptionPrice.for(SubscriptionPrice::REFERENCE_CURRENCY) # TND monthly price row
PlatformSetting.current # the singleton (annual discount = 10%)

puts "Seeding the platform admin account..."
User.find_or_create_by!(email: "admin@fitora.test") do |u|
  u.first_name = "Fitora"
  u.last_name = "Admin"
  u.password = "password123"
  u.role = :admin
  u.locale = "fr"
end

puts "Seed complete."
puts "Platform admin: admin@fitora.test / password123"
