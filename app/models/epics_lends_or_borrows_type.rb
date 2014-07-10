class EpicsLendsOrBorrowsType < ActiveRecord::Base
	set_table_name :epics_lends_or_borrows_types 
	set_primary_key :epics_lends_or_borrows_type_id

  include Epics

end
