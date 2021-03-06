PoolMadness::Application.routes.draw do

  root to: "home#index"

  # namespace :admin do
  #   resources :brackets do
  #     member do
  #       patch :promise_to_pay
  #       patch :mark_paid
  #     end
  #     collection do
  #       get :update_outcomes
  #     end
  #   end
  # end


  # match "/subscribe", to: "home#subscribe", via: :get, as: "subscribe"
  # match "/payments", to: "home#payments", via: :get, as: "payments"
  # match "/rules", to: "home#rules", via: :get, as: "rules"
  # match "/final_possibilities", via: :get, to: "home#whatif", as: "possible"

  devise_for :users, path: "auth", path_names: { sign_in: "login", sign_up: "signup" }

  resources :users
  # resources :users do
  #   resources :stripes, only: [:index]
  # end

  resources :picks, only: [:update]

  match "pools/join", to: "pools#join", via: :post, as: "join_pool"
  match "pools/invite_code", to: "pools#invite_code", via: :get, as: "invite_code"

  resources :pools, only: [:index, :show] do
    member do
      get :rules
      get :payments
    end


    resources :brackets, only: [:index, :create]
  end

  resources :brackets, except: [:index, :create]
  resources :charges, only: [:create]

  #resources :games
end
