# frozen_string_literal: true

Rails.application.routes.draw do
  scope '/api' do
    get 'sessions', to: 'sessions#current'
    post 'sessions', to: 'sessions#login'
    delete 'sessions', to: 'sessions#logout'

    post 'sessions/signup', to: 'sessions#signup'

    resources :attachments, only: %i[show create]

    get 'health', to: 'health#health'
    post 'graphql', to: 'graphql#execute'
  end

  if Rails.env.development?
    mount GraphiQL::Rails::Engine, at: "/api/graphiql", graphql_path: "/api/graphql"
  end
end
