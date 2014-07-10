class EpicsExchange < ActiveRecord::Base
  set_primary_key :epics_exchange_id
  has_one :epics_order, :foreign_key => :epics_order_id, :conditions => {:voided => 0}
  has_one :epics_stock, :foreign_key => :epics_stock_id, :conditions => {:voided => 0}

  include Epics

end
