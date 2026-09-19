require "rails_helper"

# Rules that are only conventions rot. This one is tested.
#
# A controller must never let a client choose which company a record belongs
# to, which role a staff seat holds, or any of the fields that decide who
# someone is. The tenant is derived from the token
# (Api::V1::BaseController#current_company); a role is resolved through
# `current_company.roles`. Neither is ever taken from the request body.
#
# Reads the controller sources rather than exercising endpoints, so a new
# controller is covered the day it is written, without anyone remembering to
# add a spec for it.
RSpec.describe "Strong parameters", type: :model do
  CONTROLLERS = Rails.root.glob("app/controllers/**/*.rb").freeze

  # Keys that decide ownership or identity, and so must never be mass
  # assignable. `role_id` is here because the staff controller resolves it
  # through the company's own roles instead — permitting it is fine, letting
  # it reach the model unresolved is not, and this catches the shortcut.
  FORBIDDEN = %w[
    company_id
    password_digest
    token_version
    email_verified_at
    reset_password_token_digest
    email_verification_token_digest
  ].freeze

  # `permit(...)` argument lists, flattened to the symbols inside them.
  def permitted_keys(source)
    source.scan(/\.permit\((.*?)\)/m).flatten.join(",").scan(/:([a-z_]+)/).flatten
  end

  FORBIDDEN.each do |key|
    it "no controller permits :#{key}" do
      offenders = CONTROLLERS.select { |path| permitted_keys(path.read).include?(key) }
                             .map { |path| path.relative_path_from(Rails.root).to_s }

      expect(offenders).to be_empty,
        "#{offenders.join(', ')} permits :#{key} from the request body. " \
        "It must be derived server-side, never taken from the client."
    end
  end

  it "no controller assigns a company from params" do
    offenders = CONTROLLERS.select { |path|
      path.read.match?(/company_id:\s*params\[|company:\s*Company\.find/)
    }.map { |path| path.relative_path_from(Rails.root).to_s }

    expect(offenders).to be_empty,
      "#{offenders.join(', ')} resolves a company from the request. " \
      "Use current_company."
  end

  it "every counter cache column stays out of every permit list" do
    # Taken from the associations that actually declare one, not from column
    # names ending in _count: contract_types.session_count is how many
    # sessions a plan includes, a real field an owner sets, and a name-based
    # guess would call it a counter cache.
    Rails.application.eager_load!
    counter_columns = ApplicationRecord.descendants.flat_map { |model|
      model.reflect_on_all_associations(:belongs_to).filter_map { |assoc|
        assoc.options[:counter_cache].then { |c| c == true ? "#{model.table_name}_count" : c&.to_s }
      }
    }.uniq

    expect(counter_columns).not_to be_empty, "expected at least one counter cache to exist to check against"

    offenders = CONTROLLERS.flat_map { |path|
      keys = permitted_keys(path.read)
      (keys & counter_columns).map { |key| "#{path.relative_path_from(Rails.root)} (:#{key})" }
    }

    expect(offenders).to be_empty
  end
end
