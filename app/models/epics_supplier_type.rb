class EpicsSupplierType < ActiveRecord::Base
	set_table_name :epics_supplier_types
	set_primary_key :epics_supplier_type_id
  default_scope where('voided = 0')
  has_many :epics_suppliers, :foreign_key => :epics_supplier_type_id

  include Epics

end
