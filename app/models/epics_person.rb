class EpicsPerson < ActiveRecord::Base
  set_primary_key :epics_person_id
  has_many :epics_stock_witnesses, :foreign_key => :epics_person_id, :conditions => {:voided => 0}

  include Epics

  def self.get_names(search_string)
    names = EpicsPerson.where("fname LIKE (?) OR lname LIKE (?)",
           "%#{search_string}%", "%#{search_string}%").map do |person|
            person.fname + " " + person.lname
    end


  end

  def self.get_name(search_string)
    fname = EpicsPerson.where(" fname LIKE (?)","%#{search_string}%").map{|person| person.fname}
    lname = EpicsPerson.where(" lname LIKE (?)","%#{search_string}%").map{|person| person.lname}

    return "<li></li><li>" + (fname +lname).uniq.join("</li><li>") + "</li>"
  end

end
