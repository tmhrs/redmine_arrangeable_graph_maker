# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

Rails.application.routes.draw do
  match ':controller(/:action(/:project_id))', :controller => /graph_maker/
  #match ':controller/:action/show_trend/:project_id', :controller => /graph_maker/
  match 'export' => 'graph_maker#export'
end
