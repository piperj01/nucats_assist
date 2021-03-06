# encoding: UTF-8
class User < ActiveRecord::Base
  has_many :reviewers  #really program reviewers since the reviewer model is a user + program
  belongs_to :biosketch, :class_name => "FileDocument", :foreign_key => 'biosketch_document_id'
  has_many :key_personnel
  has_many :submission_reviews, :foreign_key => 'reviewer_id'
  has_many :reviewed_submissions, :class_name => "Submission", :through => :submission_reviews, :source => :submission
  has_many :roles_users
  has_many :roles, :through => :roles_users
  has_many :logs
  
  has_many :submissions, :foreign_key => 'applicant_id'
  has_many :proxy_submissions, :class_name => "Submission", :foreign_key => 'created_id'
  attr_accessor :validate_for_applicant
  attr_accessor :validate_era_commons_name
  attr_accessor :validate_name
  attr_accessor :validate_email_attr
  
  after_save :save_documents

  named_scope :project_applicants, lambda { |*args| {:joins=>[:submissions], :conditions => ['submissions.project_id IN (:project_ids)', {:project_ids => args.first} ] }}

  default_scope :order => 'lower(users.last_name),lower(users.first_name)'
  named_scope :program_reviewers, lambda { |*args| {:joins=>:reviewers, :conditions => ['reviewers.program_id = :program_id', {:program_id => args.first} ] }}
  
  validates_presence_of :username
  validates_uniqueness_of :username
  validates_presence_of :era_commons_name, :if => :validate_era_commons
  validates_uniqueness_of :era_commons_name, :if => :validate_era_commons
  validates_presence_of :email, :if => :validate_email
  validates_uniqueness_of :email, :if => :validate_email
  validates_format_of :email, 
    :with => %r{^[a-zA-Z0-9\.\-\_][a-zA-Z0-9\.\-\_]+@[^\.]+\..+$}i, 
    :message => "Email address is not valid. Please correct",
    :if => Proc.new { |c| !c.email.blank? }
  validates_presence_of :first_name, :if => :validate_first_last
  validates_presence_of :last_name, :if => :validate_first_last
  
  def name
    [first_name, last_name].join(' ').gsub(/\'/, "’")
  end

  def sort_name
    [last_name, first_name].join(', ').gsub(/\'/, "’").strip
  end

  def short_name
    begin
      [first_name[0,1]+'.', last_name].join(' ').gsub(/\'/, "’")
    rescue
      ''
    end
  end

  def long_name
    [name, degrees].compact.join(", ").gsub(/, +$/,"").gsub(/\'/, "’")
  end
  
  def validate_first_last 
    validate_name || validate_name.nil?
  end 

  def validate_email 
    (validate_email_attr == false) ? false : true
  end 

  def validate_era_commons 
    validate_era_commons_name
  end 
  
  # this defines the connection between the model attribute exposed to the form (uploaded_photo ) 
  # and the storage fields for the file
  def uploaded_photo=(field) 
    self.photo = FileDocument.new if self.photo.nil?
    self.photo.uploaded_file = field
  end 

  def uploaded_biosketch=(field)
    if self.biosketch_document_id.nil?
      self.biosketch = FileDocument.new 
      begin
        logger.warn "creating new biosketch object for investigator"
      rescue
        puts  "creating new biosketch object for investigator"
      end
    end
    self.biosketch.uploaded_file = field
  end 

  def save_documents
    self.biosketch.save if !self.biosketch.nil? and self.biosketch.changed?
  end 
  
end
