module Epics
  
  def self.included(base)
    base.before_save :before_save_action
    base.before_create :before_create_action
  end
 
  def before_save_action
    if self.attributes.keys.include?("creator") and (self.creator.blank? || self.creator == 0) and not User.current.blank?
      self.creator = User.current.id 
    end
  end

  def before_create_action
    if self.attributes.keys.include?("creator") and (self.creator.blank? || self.creator == 0) and not User.current.blank?
      self.creator = User.current.id 
    end

    if self.attributes.keys.include?("uuid")
      self.uuid = ActiveRecord::Base.connection.select_one("SELECT UUID() as uuid")['uuid'] 
    end

    unless EpicsOrders.issue_date.blank?
      datetime = "#{EpicsOrders.issue_date} #{Time.now.strftime('%H:%M:%S')}"
    end

    if self.attributes.keys.include?("created_at") and not EpicsOrders.issue_date.blank?
      self.created_at = datetime
    end
    
    if self.attributes.keys.include?("updated_at") and not EpicsOrders.issue_date.blank?
      self.updated_at = datetime
    end
  end
  
end
