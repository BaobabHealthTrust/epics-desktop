class EpicsUserRole < ActiveRecord::Base
  set_primary_key :epics_user_role_id
  belongs_to :user, :foreign_key => :user_id
  belongs_to :epics_role, :foreign_key => :epics_role_id
  default_scope where("voided = 0")
  include Epics

  def name
     self.epics_role.role rescue "Pharmacist"
  end
end
