class EpicsContact < ActiveRecord::Base
  set_table_name :epics_contacts
  set_primary_key :epics_contact_id
  default_scope where("#{table_name}.voided = 0")

  def self.send_email
    file_names = ['items_to_expire_next_six_months.pdf','daily_dispensation.pdf',
      'received_items.pdf']
    file_names.each do |file_name|
      if File.exist?("/tmp/#{file_name}")
        EpicsContact.all.each do |contact|
          subject = "Epics Report"
          body = "Dear #{contact.title} #{contact.first_name}  #{contact.last_name} <br /><br /> Please find
                  attached a report for today"
          Notifications.notify(contact,subject,body,file_name).deliver
        end
      else
        subject = "Epics Email Error"
        Notifications.email_error(subject).deliver
      end
    end
  end
  
end
