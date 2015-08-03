Rails.application.routes.draw do
  github_authenticate do
    get '/profile' => 'users#show', as: :profile
  end

  get '/login'  => 'sessions#create', as: :login
  get '/logout' => 'sessions#destroy', as: :logout

  root to: 'sessions#create'
end
