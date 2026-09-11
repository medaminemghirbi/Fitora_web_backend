module Api
  module V1
    # One call the web/mobile clients make right after login (and on a hard
    # reload) to hydrate everything the shell needs: the user, their company,
    # branding, the resolved permission list, the enabled modules, and the
    # subscription banner state. Replaces separate /auth/me + /branding +
    # /subscription round-trips.
    class BootstrapController < BaseController
      # A locked company can still bootstrap — the client needs the payload to
      # render the "trial expired" screen. Individual feature endpoints stay
      # locked by enforce_trial_lock!.
      skip_before_action :enforce_trial_lock!

      def show
        company = current_company
        resolved = Permissions::Resolve.call(user: current_user)

        render json: {
          user: UserSerializer.new(current_user).as_json,
          company: current_user.owner? ? CompanySerializer.new(company).as_json : nil,
          branding: CompanyBrandingSerializer.new(company).as_json,
          role: resolved.role,
          permissions: resolved.permissions,
          modules: company&.enabled_module_keys || [],
          roles: (company&.roles&.ordered || []).map { |r|
            { id: r.id, key: r.key, name: r.name, permissions: r.permissions, builtin: r.builtin }
          },
          permission_catalog: Permission::CATALOG,
          subscription: subscription_json(company),
          setup: current_user.owner? ? company&.setup_state : nil,
          notifications: { unread_count: current_user.notifications.unread.count }
        }
      end

      private

      def subscription_json(company)
        subscription = company&.subscription
        return nil if subscription.nil?

        {
          status: subscription.status,
          locked: subscription.locked?,
          on_trial: subscription.on_trial?,
          trial_days_remaining: subscription.days_remaining
        }
      end
    end
  end
end
