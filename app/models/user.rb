require 'digest/sha1'
require 'digest/sha2'

class User < ActiveRecord::Base
	set_primary_key :user_id
  cattr_accessor :current
  has_one :epics_user_role
  belongs_to :openmrs_person, :foreign_key => :person_id

  require 'uuidtools'

  before_create :add_fields
  before_save :encrypt_password

  def self.check_authenticity(password, username)
    user = User.find_by_username(username)
    if !user.blank?
      if user.password == user.verify_password(password, user.salt)
        return user
      end
    end
    return nil
  end

  def verify_password(in_password, in_salt)
    new_salt = salt = Digest::SHA1.hexdigest(in_password + in_salt)
  end

  def encrypt_password
    if self.salt.blank?
      self.salt = User.random_string(10)
      self.password = encrypt(self.password, self.salt)
    end
  end

  def add_fields
    self.uuid = UUIDTools::UUID.random_create.to_s
    self.date_created = Time.now
    self.creator = User.current.id
  end

  def encrypt(password,salt)
    Digest::SHA1.hexdigest(password+salt)
  end

  def self.random_string(len)
    #generate a random password consisting of strings and digits
    chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
    newpass = ""
    1.upto(len) { |i| newpass << chars[rand(chars.size-1)] }
    return newpass
  end

end
