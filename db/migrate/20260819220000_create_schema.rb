class CreateSchema < ActiveRecord::Migration[8.0]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")
    enable_extension "btree_gist" unless extension_enabled?("btree_gist")

    create_table :users, id: :uuid do |t|
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email, null: false
      t.string :phone
      t.string :password_digest, null: false
      t.integer :role, default: 1, null: false
      t.string :locale, default: "fr", null: false
      t.boolean :active, default: true, null: false
      t.timestamps
      t.index :email, unique: true
    end

    # The gym/studio business itself. Its access status with Gerily lives
    # separately on Subscription, below — a Company having no Subscription
    # row is what "still on the free trial" means.
    create_table :companies, id: :uuid do |t|
      t.references :owner, type: :uuid, null: false, foreign_key: { to_table: :users }, index: { unique: true }
      t.string :name, null: false
      t.text :description
      t.string :phone
      t.string :email
      t.string :country
      t.string :city
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.string :address
      t.string :timezone, default: "Africa/Tunis", null: false
      t.string :currency, default: "TND", null: false
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    create_table :locations, id: :uuid do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.text :description
      t.string :phone
      t.string :email
      t.string :address
      t.string :city
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.string :timezone, default: "Africa/Tunis", null: false
      t.boolean :active, default: true, null: false
      t.time :business_hours_start, default: "2000-01-01 06:00:00", null: false
      t.time :business_hours_end, default: "2000-01-01 22:00:00", null: false
      t.timestamps
    end

    create_table :activities, id: :uuid do |t|
      t.references :location, type: :uuid, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.text :description
      t.integer :activity_type, default: 0, null: false
      t.integer :duration, null: false
      t.integer :capacity, default: 1, null: false
      t.boolean :active, default: true, null: false
      t.integer :booking_mode, default: 0, null: false
      t.string :emoji
      t.timestamps
    end

    create_table :coaches, id: :uuid do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true, index: true
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email
      t.string :phone
      t.text :bio
      t.string :photo_url
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    create_table :coach_locations, id: :uuid do |t|
      t.references :coach, type: :uuid, null: false, foreign_key: true, index: true
      t.references :location, type: :uuid, null: false, foreign_key: true, index: true
      t.timestamps
      t.index [ :coach_id, :location_id ], unique: true
    end

    # A company's access status with Gerily — no plans, no tiers, no limits.
    # expires_at doubles as the free-trial deadline; once it passes, only a
    # platform admin manually setting a new expires_at/status unlocks the
    # account again (see Subscription#locked? / BaseController#enforce_trial_lock!).
    create_table :subscriptions, id: :uuid do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true, index: { unique: true }
      t.integer :status, default: 0, null: false
      t.datetime :starts_at, null: false
      t.datetime :expires_at
      t.timestamps
    end

    create_table :recurring_schedules, id: :uuid do |t|
      t.references :activity, type: :uuid, null: false, foreign_key: true, index: true
      t.references :location, type: :uuid, null: false, foreign_key: true, index: true
      t.references :coach, type: :uuid, foreign_key: true, index: true
      t.references :company, type: :uuid, null: false, foreign_key: true, index: true
      t.integer :weekdays, default: [], null: false, array: true
      t.time :start_time, null: false
      t.integer :recurrence_type, default: 0, null: false
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.boolean :active, default: true, null: false
      t.timestamps
      t.index :weekdays, using: :gin
    end

    create_table :sessions, id: :uuid do |t|
      t.references :activity, type: :uuid, null: false, foreign_key: true, index: true
      t.references :location, type: :uuid, null: false, foreign_key: true, index: true
      t.references :coach, type: :uuid, foreign_key: true, index: true
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.integer :capacity, null: false
      t.decimal :price, precision: 10, scale: 2, default: "0.0", null: false
      t.integer :status, default: 0, null: false
      t.references :recurring_schedule, type: :uuid, foreign_key: true, index: true
      t.timestamps
      t.index :starts_at
      t.exclusion_constraint "coach_id WITH =, tsrange(starts_at, ends_at) WITH &&",
                              where: "(status = 0) AND (coach_id IS NOT NULL)", using: :gist,
                              name: "no_overlapping_coach_sessions"
    end

    create_table :clients, id: :uuid do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true, index: true
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email
      t.string :phone
      t.date :date_of_birth
      t.string :gender
      t.string :address
      t.string :emergency_contact_name
      t.string :emergency_contact_phone
      t.text :notes
      t.boolean :active, default: true, null: false
      t.datetime :joined_at, null: false
      t.timestamps
      t.index [ :company_id, :first_name, :last_name ]
    end

    # Client-facing membership plan — "Abonnement". billing_period replaces
    # the old free-form duration_days (monthly/quarterly/semi_annual/yearly
    # only, per the new product decision); session_count is the new
    # "nombre de séances" attribute that replaces the removed
    # Package/ClientPackage credits system — a plan can now cap total
    # sessions directly instead of needing a separate package purchase.
    create_table :membership_plans, id: :uuid do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.text :description
      t.decimal :price, precision: 10, scale: 2, default: "0.0", null: false
      t.string :currency, default: "TND", null: false
      t.integer :billing_period, default: 0, null: false
      t.integer :session_count
      t.boolean :unlimited_bookings, default: false, null: false
      t.integer :booking_limit
      t.boolean :priority_booking, default: false, null: false
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    create_table :membership_plan_locations, id: :uuid do |t|
      t.references :membership_plan, type: :uuid, null: false, foreign_key: true, index: true
      t.references :location, type: :uuid, null: false, foreign_key: true, index: true
      t.timestamps
      t.index [ :membership_plan_id, :location_id ], unique: true, name: "index_plan_locations_unique"
    end

    create_table :membership_plan_activities, id: :uuid do |t|
      t.references :membership_plan, type: :uuid, null: false, foreign_key: true, index: true
      t.references :activity, type: :uuid, null: false, foreign_key: true, index: true
      t.timestamps
      t.index [ :membership_plan_id, :activity_id ], unique: true, name: "index_plan_activities_unique"
    end

    create_table :memberships, id: :uuid do |t|
      t.references :client, type: :uuid, null: false, foreign_key: true, index: true
      t.references :membership_plan, type: :uuid, null: false, foreign_key: true, index: true
      t.references :company, type: :uuid, null: false, foreign_key: true, index: true
      t.integer :status, default: 0, null: false
      t.datetime :starts_at
      t.datetime :expires_at
      t.integer :remaining_bookings
      t.boolean :auto_renew, default: false, null: false
      t.decimal :discount, precision: 10, scale: 2, default: "0.0", null: false
      t.decimal :final_price, precision: 10, scale: 2
      t.integer :payment_status, default: 0, null: false
      t.references :created_by, type: :uuid, foreign_key: { to_table: :users }, index: true
      t.timestamps
      t.index [ :client_id, :status ]
    end

    create_table :bookings, id: :uuid do |t|
      t.references :client, type: :uuid, null: false, foreign_key: true, index: true
      t.references :session, type: :uuid, null: false, foreign_key: true, index: true
      t.integer :status, default: 0, null: false
      t.decimal :amount, precision: 10, scale: 2, default: "0.0", null: false
      t.string :currency, default: "TND", null: false
      t.references :membership, type: :uuid, foreign_key: true, index: true
      t.integer :payment_status, default: 0, null: false
      t.timestamps
      t.index [ :session_id, :client_id ], unique: true, where: "(status = 0)", name: "index_bookings_on_session_id_and_client_id_when_held"
    end

    create_table :payments, id: :uuid do |t|
      t.references :client, type: :uuid, null: false, foreign_key: true, index: true
      t.references :company, type: :uuid, null: false, foreign_key: true, index: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :currency, default: "TND", null: false
      t.integer :status, default: 0, null: false
      t.datetime :paid_at
      t.references :membership, type: :uuid, foreign_key: true, index: true
      t.references :booking, type: :uuid, foreign_key: true, index: true
      t.integer :payment_method, default: 0, null: false
      t.text :notes
      t.references :created_by, type: :uuid, foreign_key: { to_table: :users }, index: true
      t.timestamps
    end

    create_table :staff_members, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true, index: { unique: true }
      t.references :company, type: :uuid, null: false, foreign_key: true, index: true
      t.references :coach, type: :uuid, foreign_key: true, index: true
      t.integer :role, default: 0, null: false
      t.boolean :active, default: true, null: false
      t.timestamps
    end

    create_table :staff_member_locations, id: :uuid do |t|
      t.references :staff_member, type: :uuid, null: false, foreign_key: true, index: true
      t.references :location, type: :uuid, null: false, foreign_key: true, index: true
      t.timestamps
      t.index [ :staff_member_id, :location_id ], unique: true, name: "index_staff_member_locations_unique"
    end

    create_table :attendance_records, id: :uuid do |t|
      t.references :booking, type: :uuid, null: false, foreign_key: true, index: { unique: true }
      t.integer :status, default: 0, null: false
      t.datetime :checked_in_at
      t.datetime :checked_out_at
      t.references :marked_by, type: :uuid, foreign_key: { to_table: :users }, index: true
      t.timestamps
    end

    create_table :audit_logs, id: :uuid do |t|
      t.references :company, type: :uuid, null: false, foreign_key: true, index: true
      t.references :user, type: :uuid, foreign_key: true, index: true
      t.string :action, null: false
      t.string :auditable_type, null: false
      t.uuid :auditable_id, null: false
      t.jsonb :metadata, default: {}, null: false
      t.datetime :created_at, null: false
      t.index [ :auditable_type, :auditable_id ]
      t.index [ :company_id, :created_at ]
    end
  end
end
