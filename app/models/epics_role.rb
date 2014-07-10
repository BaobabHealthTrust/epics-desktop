class EpicsRole < ActiveRecord::Base
  set_primary_key :epics_role_id

  include Epics

end
