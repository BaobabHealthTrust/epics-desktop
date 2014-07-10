class EpicsProductType < ActiveRecord::Base
	set_table_name :epics_product_types
 	set_primary_key :epics_product_type_id
  default_scope where('voided = 0')
  has_many :epics_products, :foreign_key => :epics_product_type_id, :conditions => {:voided => 0}

  include Epics

end
