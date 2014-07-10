class EpicsOrders < ActiveRecord::Base
	set_table_name :epics_orders 
	set_primary_key :epics_order_id
  cattr_accessor :issue_date

  default_scope where("#{table_name}.voided = 0")
  belongs_to :epics_order_types, :foreign_key => :epics_order_type_id, :conditions => {:voided => 0}
  has_many :epics_product_orders, :class_name => "EpicsProductOrders", :foreign_key => :epics_order_id, :conditions => {:voided => 0}

  include Epics

end
