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
          # Which parts of the product this tenant has turned on. Sent to
          # everyone, not just the owner (whose `company` payload also
          # carries them): a receptionist needs to know rooms exist as much
          # as the owner does. It says what the product OFFERS here, never
          # who may use it — that is `permissions`, resolved separately.
          features: company&.settings&.features || {},
          roles: (company&.roles&.ordered || []).map { |r|
            { id: r.id, key: r.key, name: r.name, permissions: r.permissions, builtin: r.builtin }
          },
          permission_catalog: Permission::CATALOG,
          subscription: subscription_json(company),
          onboarding: current_user.owner? ? company&.onboarding_state&.as_json : nil,
          notifications: { unread_count: current_user.notifications.unread.count }
        }
      end

      private

      def subscription_json(company)
        subscription = company&.subscription
        return nil if subscription.nil?

        {
          active: subscription.active,
          locked: subscription.locked?,
          lock_reason: subscription.lock_reason,
          # Enough for the shell to warn before the door shuts, rather than
          # leaving the owner to discover it mid-task.
          current_period_paid: subscription.current_period_paid?,
          days_before_lock: subscription.days_before_lock
        }
      end
    end
  end
end
