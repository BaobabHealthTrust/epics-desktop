class EpicsItemCost < ActiveRecord::Base
	set_table_name :epics_item_costs 
	set_primary_key :epics_item_cost_id
  default_scope where("#{table_name}.voided = 0")
  belongs_to :epics_products, :foreign_key => :epics_products_id, :conditions => {:voided => 0}

  include Epics

end
