EpicsBdeTool::Application.routes.draw do

  get "stock_details/edit_current_quantity"
  post "stock_details/board_off_stock"
  get "stock_details/edit_stock_details"
  post "stock_details/save_edited_stock_details"
  post "stock_details/void"
  get "stock_details/void_transaction"

  get "product/search"
  get "product/select"
  get "product/find_by_name_or_code"
  get "product/data_entry"
  post "product/data_entry"
  post "product/save_transaction"
  get "product/stock_card"
  post "product/stock_card"
  get "product/view"
  post "product/view"


  get "home/index"

  ######## person #########

  get "person/add_person"
  post "person/new_person"
  get "person/get_name"

  ######## person #########

  ######## user ########
  match '/login' => "user#login"
  match '/logout' => "user#logout"
  post "user/authenticate"
  get "user/enter_workstation"
  post "user/locations"
  get "/user/new"
  post "user/create"
  get "user/summary"
  get "user/edit"
  get "user/change_password"
  post "user/change_password"
  get "user/change_username"
  post "user/change_username"
  get "user/change_user_role"
  post "user/change_user_role"
  get "user/void"
  ######## user end ########


  ######### location_type start ########
  get "location_type/index"
  get "location_type/new"
  post "location_type/create"
  get "location_type/edit"
  post "location_type/update"
  get "location_type/void"
  ######### location_type end ########

  ######## location start ###########
  get "location/index"
  get "location/new"
  post "location/create"
  get "location/edit"
  post "location/update"
  get "location/void"
  get "location/search"
  get "location/print_location_menu"
  post "location/print_location"
  get "location/location_label"
  ######## location end #######


  ########### reports start #########
  get "report/drug_availability"
  get "report/drug_availability_printable"
  post "report/drug_availability_printable"
  post "report/daily_dispensation"
  post "report/daily_dispensation_printable"
  get "report/store_room"
  post "report/store_room_printable"
  get "report/view_alerts"
  get "report/select_store"
  match 'alerts/:name' => 'report#alerts', :as => :alerts
  get "report/select_date_range"
  post "report/monthly_report"
  post "report/print_monthly_report"
  get "report/monthly_report_printable"
  post "report/monthly_report_printable"
  get "report/select_daily_dispensation_date"
  match 'drug_daily_dispensation/:id/:date' => 'report#drug_daily_dispensation', :as => :drug_daily_dispensation
  get "report/expired_items"
  get "report/select_date_ranges"
  post "report/disposed_items"
  post "report/print_drug_availability_report"
  post "report/print_store_room_report"
  get "report/store_room_printable"
  post "report/print_daily_dispensation_report"
  get "report/daily_dispensation_printable"
  get 'report/missing_items'
  post 'report/print_disposed_items_report'
  get 'report/disposed_items_printable'
  post "report/audit"
  post "report/received_items"
  post "report/print_expired_items_report"
  get "report/expired_items_printable"
  get "report/items_to_expire_next_six_months_attachment"
  post "report/items_to_expire_next_six_months_attachment"
  get "report/items_to_expire_next_six_months_to_pdf"
  post "report/items_to_expire_next_six_months_to_pdf"
  get "report/daily_dispensation_attachment"
  post "report/daily_dispensation_attachment"
  get "report/daily_dispensation_to_pdf"
  post "report/daily_dispensation_to_pdf"
  get "report/received_items_attachment"
  post "report/received_items_attachment"
  get "report/received_items_to_pdf"
  post "report/received_items_to_pdf"
  get "report/monthly_report_attachment"
  get "report/monthly_report_to_pdf"
  ########### reports end #########

  root :to => 'home#index'
end
