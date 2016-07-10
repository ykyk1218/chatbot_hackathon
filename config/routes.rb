Rails.application.routes.draw do
  root 'welcome#index'
  post '/callback' => 'webhook#callback'
  get '/lunch_cal' => 'webhook#lunch_cal'
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
