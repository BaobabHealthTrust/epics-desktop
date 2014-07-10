class EpicsStockDetails < ActiveRecord::Base
	set_table_name :epics_stock_details
 	set_primary_key :epics_stock_details_id
  #default_scope where('voided = 0')
  default_scope where("#{table_name}.voided = 0")
  belongs_to :epics_stock
  belongs_to :epics_product, :foreign_key => :epics_products_id, :conditions => {:voided => 0}
  belongs_to :epics_location, :foreign_key => :epics_location_id, :conditions => {:voided => 0}
  has_one :epics_stock_expiry_date, :class_name => 'EpicsStockExpiryDates' ,
    :foreign_key => :epics_stock_details_id, :conditions => {:voided => 0}

  include Epics

  def self.stocks_in_location(location)
     products = self.where("epics_location_id = ? AND current_quantity > 0", location)
  end
end
