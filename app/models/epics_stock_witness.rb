class EpicsStockWitness < ActiveRecord::Base
  set_table_name :epics_stock_witnesses
  set_primary_key :epics_stock_witness_id
  belongs_to :epics_stock
  belongs_to :epics_person
  
  include Epics

end
