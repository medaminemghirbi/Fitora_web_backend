require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  # The Sidekiq dashboard. Open in development; HTTP basic auth everywhere
  # else, and only mounted at all once SIDEKIQ_WEB_PASSWORD is set.
  unless Rails.env.development?
    Sidekiq::Web.use Rack::Auth::Basic do |user, password|
      expected_user = ENV.fetch("SIDEKIQ_WEB_USER", "fitora")
      expected_pass = ENV["SIDEKIQ_WEB_PASSWORD"].to_s
      expected_pass.present? &&
        ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(user), ::Digest::SHA256.hexdigest(expected_user)) &
        ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(password), ::Digest::SHA256.hexdigest(expected_pass))
    end
  end
  mount Sidekiq::Web => "/sidekiq" if Rails.env.development? || ENV["SIDEKIQ_WEB_PASSWORD"].present?

  namespace :api do
    namespace :v1 do
      post "auth/register", to: "auth#register"
      post "auth/login", to: "auth#login"
      post "auth/logout", to: "auth#logout"
      get "auth/me", to: "auth#me"
      get "me/permissions", to: "auth#permissions"
      get "bootstrap", to: "bootstrap#show"
      get "app_version", to: "app_version#show"

      # Account recovery / email confirmation (token in the URL, unauthenticated)
      resources :email_verifications, only: [ :create, :update ], param: :token
      resources :password_resets, only: [ :create, :update ], param: :token

      resources :notifications, only: [ :index, :show ] do
        member { patch :read }
        collection do
          post :read_all
          get :unread_count
        end
      end

      resource :company, only: [ :show, :update ]
      # Plural: an owner can run more than one company now (see
      # User#company_limit) — :show/:update above always act on whichever
      # one is currently active; these list/create/switch between them.
      resources :companies, only: [ :index, :create ] do
        member { post :switch }
      end
      get "branding", to: "branding#show"

      # A gym asking for a demo or a quote — no login, by definition: this
      # is how an account gets opened at all (see Leads::Convert).
      resources :leads, only: [ :create ]
      post "onboarding/dismiss", to: "onboarding#dismiss"
      resources :activities
      resources :coaches do
        member do
          post :login, to: "coaches#set_login"
        end
      end
      resources :sessions, only: [ :index, :show, :create, :update ] do
        collection do
          get :schedule_pdf
        end
        member do
          post :cancel
        end
      end
      resources :bookings, only: [ :index, :show, :create ] do
        member do
          post :cancel
          post :remind
        end
      end
      resources :clients, only: [ :index, :show, :create, :update ]

      get "data_exchange/:entity/template", to: "data_exchange#template"
      get "data_exchange/:entity/export", to: "data_exchange#export"
      post "data_exchange/:entity/import", to: "data_exchange#import"

      get "subscription", to: "subscription#show"
      post "subscription/request_upgrade", to: "subscription#request_upgrade"
      delete "subscription/request_upgrade", to: "subscription#cancel_upgrade"

      resources :contract_types, only: [ :index, :show, :create, :update ]
      resources :contracts, only: [ :index, :show, :create, :update, :destroy ] do
        member do
          post :renew
          post :cancel
          get :receipt
        end
      end
      resources :payments, only: [ :index, :show, :create ] do
        member do
          post :refund
        end
      end

      resources :staff, only: [ :index, :show, :create, :update ]
      resources :roles, only: [ :index, :create, :update, :destroy ]

      resources :attendance, only: [ :index, :create ]
      resources :recurring_schedules, only: [ :index, :create, :update ]
      resources :audit_logs, only: [ :index ]
      resources :app_updates, only: [ :index ]
      resources :support_tickets, only: [ :index, :create ] do
        member do
          get "attachments/:attachment_id", action: :attachment, as: :attachment
        end
      end

      # A member's own app: their gym's schedule, their bookings, their file.
      # No directory and no self-signup — the gym enables the account from
      # the member's own record (Api::V1::ClientsController#update).
      namespace :me do
        resource :profile, only: [ :show ]
        resources :sessions, only: [ :index ]
        resources :bookings, only: [ :index, :create ] do
          member { post :cancel }
        end
      end

      namespace :owner do
        get "dashboard", to: "dashboard#show"
        get "revenue", to: "revenue#show"
        get "reports/export", to: "reports#export"
      end

      namespace :admin do
        resources :companies, only: [ :index, :show ] do
          member do
            patch :subscription, to: "companies#update_subscription"
            patch :settings, to: "companies#update_settings"
            patch :debt, to: "companies#update_debt"
            patch :company_limit, to: "companies#update_company_limit"
            post :impersonate, to: "companies#impersonate"
          end
        end
        get "subscription_pricing", to: "subscription_pricing#show"
        patch "subscription_pricing", to: "subscription_pricing#update"
        resources :app_updates, only: [ :index, :create ]
        resources :leads, only: [ :index, :update ] do
          member { post :convert }
        end
        resources :support_tickets, only: [ :index ] do
          member do
            patch :resolve
            get "attachments/:attachment_id", action: :attachment, as: :attachment
          end
        end
      end
    end
  end

  # SPA fallback — any non-API HTML GET that isn't a real file in public/
  # serves the Angular app's index.html so client-side routes work on hard
  # refresh and deep links. Must stay last.
  get "*path", to: "spa#index", format: false, constraints: ->(req) {
    req.get? && req.format.html? &&
      %w[/api /cable /rails /up /sidekiq].none? { |p| req.path.start_with?(p) }
  }
end
