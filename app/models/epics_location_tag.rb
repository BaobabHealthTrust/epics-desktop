class EpicsLocationTag < ActiveRecord::Base
  set_primary_key :location_tag_id
  belongs_to :epics_location, :foreign_key => :location_id
end
