class EpicsLendsOrBorrows < ActiveRecord::Base
	set_table_name :epics_lends_or_borrows
	set_primary_key :epics_lends_or_borrows_id
  has_one :epics_lend_borrow_authorizer, :conditions => {:voided => 0}
  belongs_to :epics_lends_or_borrows_type, :foreign_key => :epics_lends_or_borrows_type_id, :conditions => {:voided => 0}
  default_scope where("#{table_name}.voided = 0")

  include Epics

  def authorizer
    self.epics_lend_borrow_authorizer.authorizer
  end

end
