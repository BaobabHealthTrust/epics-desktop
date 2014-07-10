class EpicsLendBorrowAuthorizer < ActiveRecord::Base
  set_table_name :epics_lend_borrow_authorizers
  set_primary_key :authorization_id
  default_scope where('voided = 0')
  belongs_to :epics_lends_or_borrows, :foreign_key => :epics_lends_or_borrows_id, :conditions => {:voided => 0}
  belongs_to :epics_person, :foreign_key => :authorizer, :conditions => {:voided => 0}

  include Epics

  before_save :set_uuid

  def set_uuid
    if self.authorizer == User.current.id
      self.authorized = true
    end
  end

end
