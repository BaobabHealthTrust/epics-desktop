class HomeController < ApplicationController
  def index
    @application = [
        ["Enter Transaction",'/product/select',"search.png"],
        ["Stock Card",'/product/search',"search.png"]
    ]

    @reports = [
        ["Drug Availability","/report/select_store?report=drug_availability","available_drugs.png"],
        ["Daily Dispensation","/report/select_daily_dispensation_date","daily_dispense.png"],
        ["Central Hospital Monthly LMIS Report","/report/select_date_range","monthly_report.png"],
        ["Audit Report","/report/select_date_ranges?name=audit","audit_report.png"],
        ["View Received/Issued","/report/select_date_ranges?name=received_items","view_issued_received.png"],
        ["View Store Room","/report/select_store","first_aid_kit_icon.png"],
        ["View expired items","report/expired_items","expired.jpeg"],
        ["View Disposed items","/report/select_date_ranges","disposal.png"],
        ["View alerts","/report/view_alerts","alert_list.png"]
    ]

    @activities = [
        ["Change Password", "user/change_password", "change_password.png"],
        ["Edit Username", "user/change_username", "change_username.png"]
    ]

    @administration = [
        ["Add Items","/product/new","add_items.png"],
        ["Print Location","/location/print_location_menu","emblem_print.png"],
        ["Set Contacts","/contact/index","contacts.png"],
        ["Edit Expiry Date","/product/select_drug_menu","edit_expiry_date.png"]
    ]

    if User.current.epics_user_role.name == "Administrator"
      @administration << ["Set Item Units","/product_units/index","units_icon.png"] << ["Set Item Types","/product_type/index","set_items.png"]
      @administration << ["Set Item Categories","/product_category/index","Item_categories.png"]# << ["Set Order Types","/order_type/index","order_type.png"]
      @administration << ["Set Supplier Types","/supplier_type/index","supplier_type.png"] << ["Set Suppliers","/supplier/index","suppliers.png"]
      @administration << ["Set Locations","/location/index","sysuser.png"] << ["Set Location Types","/location_type/index","workstations.png"]
      @administration << ["Add User","/user/new","add_user.png"]
      @administration << ["Edit User","/user/edit","user_edit2.png"]

    end

    @buttons_count = @application.length
    @buttons_count = @reports.length if @reports.length > @buttons_count
    @buttons_count = @activities.length if @activities.length > @buttons_count
    @buttons_count = @administration.length if @administration.length > @buttons_count

    render :layout => false
  end

end
