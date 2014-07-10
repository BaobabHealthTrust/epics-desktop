class EpicsLocationType < ActiveRecord::Base
  set_table_name :epics_location_types
  set_primary_key :epics_location_type_id
  default_scope where('voided = 0')
  has_many :epics_locations, :foreign_key => :epics_location_type_id, :conditions => {:voided => 0}

  include Epics

end
