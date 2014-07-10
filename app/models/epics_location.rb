class EpicsLocation < ActiveRecord::Base
  set_table_name :epics_locations
  set_primary_key :epics_location_id
  default_scope where('voided = 0')
  belongs_to :epics_location_type, :foreign_key => :epics_location_type_id
  has_many :epics_stock_details, :foreign_key => :epics_location_id, :conditions => {:voided => 0}

  include Epics

end
