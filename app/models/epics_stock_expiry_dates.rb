class EpicsStockExpiryDates < ActiveRecord::Base
	set_table_name :epics_stock_expiry_dates 
  set_primary_key :epics_stock_expiry_date_id
  default_scope where("#{table_name}.voided = 0")
  belongs_to :epics_stock_details, :foreign_key => :epics_stock_details_id, :conditions => {:voided => 0}

  include Epics

end
