# Fitora is moving from "one owner, one company" to owner-level tiers
# capping how many companies an owner can run (1 / 3 / unlimited), each
# tier with its own price. SubscriptionPrice was one row per currency;
# it becomes one row per (currency, company_limit).
#
# company_limit uses 0 as the "unlimited" sentinel rather than NULL —
# Postgres doesn't treat NULL as equal to NULL for uniqueness purposes, so
# a plain unique index on [currency, company_limit] would silently allow
# duplicate "unlimited" rows per currency if NULL meant unlimited instead.
#
# Every existing row represents today's only tier (a single company), so
# it backfills as company_limit: 1 — no gap for currencies already priced.
class AddCompanyLimitTierToSubscriptionPrices < ActiveRecord::Migration[8.0]
  def up
    add_column :subscription_prices, :company_limit, :integer, null: false, default: 1
    execute "UPDATE subscription_prices SET company_limit = 1"

    remove_index :subscription_prices, :currency
    add_index :subscription_prices, [ :currency, :company_limit ], unique: true, name: "index_subscription_prices_on_currency_and_tier"
  end

  def down
    remove_index :subscription_prices, name: "index_subscription_prices_on_currency_and_tier"
    execute "DELETE FROM subscription_prices WHERE company_limit <> 1"
    add_index :subscription_prices, :currency, unique: true
    remove_column :subscription_prices, :company_limit
  end
end
