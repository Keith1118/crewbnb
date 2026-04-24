Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: "users/registrations",
    sessions: "users/sessions"
  }

  root "pages#home"

  # Static pages
  get "about", to: "pages#about", as: :about
  get "contact", to: "pages#contact", as: :contact
  post "contact", to: "pages#submit_contact"
  get "how-it-works", to: "pages#how_it_works", as: :how_it_works
  get "help", to: "pages#help", as: :help_page
  get "safety", to: "pages#safety", as: :safety
  get "privacy", to: "pages#privacy", as: :privacy
  get "terms", to: "pages#terms", as: :terms
  get "cookies", to: "pages#cookies", as: :cookies_policy

  resources :properties, only: [:index, :show] do
    resources :bookings, only: [:new, :create]
    resources :reviews, only: [:new, :create]
    member do
      post :favorite
      delete :unfavorite
    end
  end

  resources :bookings, only: [:index, :show, :update] do
    resource :payment, only: [:new, :create] do
      get :complete
    end
    resources :reviews, only: [:new, :create]
  end

  resources :conversations, only: [:index, :show, :create] do
    resources :messages, only: [:create]
  end

  namespace :host do
    root "dashboard#index"
    resources :properties
    resources :bookings, only: [:index, :show, :update]
  end

  namespace :admin do
    root "dashboard#index"
    resources :users
    resources :properties, only: [:index, :show, :update, :destroy]
    resources :bookings, only: [:index, :show]
    resources :reviews, only: [:index, :destroy]
    resources :contact_submissions, only: [:index, :show, :destroy]
  end

  namespace :webhooks do
    resource :stripe, only: [:create], controller: "stripe"
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
