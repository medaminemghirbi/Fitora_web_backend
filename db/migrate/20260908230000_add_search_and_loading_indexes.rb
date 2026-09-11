class AddSearchAndLoadingIndexes < ActiveRecord::Migration[8.0]
  # pg_trgm — every text search in this app is a Ruby-level ILIKE '%term%'
  # (Client.search, Company.search, Supplier.search, plus a handful of
  # inline ILIKE joins in
  # bookings/payments/contracts/library_documents controllers). A plain
  # btree index can't serve a leading-wildcard match; a GIN trigram index
  # can — this is the index this app's actual search queries need, not a
  # generic "add more indexes" pass.
  def up
    enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")

    # ---- Search — one GIN trigram index per column an ILIKE clause hits --
    add_index :clients, :first_name, using: :gin, opclass: :gin_trgm_ops, name: "index_clients_on_first_name_trgm"
    add_index :clients, :last_name, using: :gin, opclass: :gin_trgm_ops, name: "index_clients_on_last_name_trgm"
    add_index :clients, :phone, using: :gin, opclass: :gin_trgm_ops, name: "index_clients_on_phone_trgm"
    add_index :clients, :email, using: :gin, opclass: :gin_trgm_ops, name: "index_clients_on_email_trgm"

    # Company.search joins users and ILIKEs both sides (admin's company list).
    add_index :companies, :name, using: :gin, opclass: :gin_trgm_ops, name: "index_companies_on_name_trgm"
    add_index :companies, :city, using: :gin, opclass: :gin_trgm_ops, name: "index_companies_on_city_trgm"
    add_index :users, :first_name, using: :gin, opclass: :gin_trgm_ops, name: "index_users_on_first_name_trgm"
    add_index :users, :last_name, using: :gin, opclass: :gin_trgm_ops, name: "index_users_on_last_name_trgm"
    add_index :users, :email, using: :gin, opclass: :gin_trgm_ops, name: "index_users_on_email_trgm"

    add_index :suppliers, :name, using: :gin, opclass: :gin_trgm_ops, name: "index_suppliers_on_name_trgm"
    add_index :suppliers, :category, using: :gin, opclass: :gin_trgm_ops, name: "index_suppliers_on_category_trgm"
    add_index :suppliers, :contact_name, using: :gin, opclass: :gin_trgm_ops, name: "index_suppliers_on_contact_name_trgm"
    add_index :suppliers, :phone, using: :gin, opclass: :gin_trgm_ops, name: "index_suppliers_on_phone_trgm"
    add_index :suppliers, :email, using: :gin, opclass: :gin_trgm_ops, name: "index_suppliers_on_email_trgm"

    add_index :library_documents, :title, using: :gin, opclass: :gin_trgm_ops, name: "index_library_documents_on_title_trgm"
    add_index :library_documents, :reference_number, using: :gin, opclass: :gin_trgm_ops,
                                                       name: "index_library_documents_on_reference_number_trgm"

    add_index :activities, :name, using: :gin, opclass: :gin_trgm_ops, name: "index_activities_on_name_trgm"
    add_index :contract_types, :name, using: :gin, opclass: :gin_trgm_ops, name: "index_contract_types_on_name_trgm"

    # ---- Data loading — "recent N for this company" / range-scan patterns
    #      the dashboard and list pages actually run -------------------------
    # Dashboard::Statistics#recent_clients — company.clients.order(created_at: :desc).limit(5)
    add_index :clients, [ :company_id, :created_at ], name: "index_clients_on_company_id_and_created_at"
    # Dashboard::Statistics#recent_payments — company.payments.paid.recent.limit(5)
    add_index :payments, [ :company_id, :status, :created_at ], name: "index_payments_on_company_id_and_status_and_created_at"
    # Dashboard::Statistics#contracts_expiring_soon — currently_active.where(expires_at: window)
    add_index :contract_periods, [ :status, :expires_at ], name: "index_contract_periods_on_status_and_expires_at"
  end

  def down
    remove_index :clients, name: "index_clients_on_first_name_trgm"
    remove_index :clients, name: "index_clients_on_last_name_trgm"
    remove_index :clients, name: "index_clients_on_phone_trgm"
    remove_index :clients, name: "index_clients_on_email_trgm"
    remove_index :companies, name: "index_companies_on_name_trgm"
    remove_index :companies, name: "index_companies_on_city_trgm"
    remove_index :users, name: "index_users_on_first_name_trgm"
    remove_index :users, name: "index_users_on_last_name_trgm"
    remove_index :users, name: "index_users_on_email_trgm"
    remove_index :suppliers, name: "index_suppliers_on_name_trgm"
    remove_index :suppliers, name: "index_suppliers_on_category_trgm"
    remove_index :suppliers, name: "index_suppliers_on_contact_name_trgm"
    remove_index :suppliers, name: "index_suppliers_on_phone_trgm"
    remove_index :suppliers, name: "index_suppliers_on_email_trgm"
    remove_index :library_documents, name: "index_library_documents_on_title_trgm"
    remove_index :library_documents, name: "index_library_documents_on_reference_number_trgm"
    remove_index :activities, name: "index_activities_on_name_trgm"
    remove_index :contract_types, name: "index_contract_types_on_name_trgm"

    remove_index :clients, name: "index_clients_on_company_id_and_created_at"
    remove_index :payments, name: "index_payments_on_company_id_and_status_and_created_at"
    remove_index :contract_periods, name: "index_contract_periods_on_status_and_expires_at"

    disable_extension "pg_trgm"
  end
end
