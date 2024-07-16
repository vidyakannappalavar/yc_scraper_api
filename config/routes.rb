Rails.application.routes.draw do
    get '/yc_companies', to: 'companies#scrape'
end
  