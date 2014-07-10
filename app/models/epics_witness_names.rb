class EpicsWitnessNames < ActiveRecord::Base
  set_table_name :epics_witness_names
  set_primary_key :epics_witness_name_id
  belongs_to :epics_stock

  include Epics

end
