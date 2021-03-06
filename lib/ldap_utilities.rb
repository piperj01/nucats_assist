require 'net/ldap'
require 'config' # has cleanup_campus method
require 'ldap_config'

def GetLDAPentry(uid)
  return nil if !ldap_perform_search? 
  return nil if uid.blank? 
  ldap_connection = Net::LDAP.new( :host => ldap_host() )
  id_filter = Net::LDAP::Filter.eq( "uid", uid)
  return ldap_connection.search( :base => ldap_treebase(), :filter => id_filter)
end

def GetLDAPentryFromEmail(email)
  return nil if !ldap_perform_search? 
  return nil if email.blank? 
  ldap_connection = Net::LDAP.new( :host => ldap_host() )
  mail_filter = Net::LDAP::Filter.eq( "mail", email)
  return ldap_connection.search( :base => ldap_treebase(), :filter => mail_filter)
end

def GetLDAPentryFromName(name)
  return nil if !ldap_perform_search?  
  return nil if name.blank? 
  ldap_connection = Net::LDAP.new( :host => ldap_host() )
  cn_filter = Net::LDAP::Filter.eq( "cn", name)
  return ldap_connection.search( :base => ldap_treebase(), :filter => cn_filter)
end

def CleanLDAPvalue(val)
  return nil if val.nil?
  if val.kind_of?(Array) then
    return nil if val.length == 0
    val=CleanLDAPvalue(val[0])
  else
    val.gsub(/[\n-\[\]]*/,"").strip
  end
  return val
end

def CleanLDAPrecord(rec)
  # results are a hash
  rec.each  do |key,value| 
     rec[key]=CleanLDAPvalue(rec[key]) 
  end
  return rec
end

def AddToLDAPrecord(rec, keys, defaultval=nil)
  # results are a hash
  reckeys = Array.new
  rec.each {|x,y| reckeys << x.to_s.downcase }
  keys.each  do |key| 
     rec[key] = defaultval  if !reckeys.include?(key.downcase)
  end
  return rec
end

# may need to adapt the ldap attributes to the Investigator data model
def BuildPIobject(pi_data)
  puts "BuildPIobject: this shouldn't happen - pi_data was nil" if pi_data.nil?
  raise "BuildPIobject: this shouldn't happen - pi_data was nil" if pi_data.nil?
  thePI = nil
  thePI = User.find_by_username(pi_data.uid)
  begin 
    if thePI.nil? || thePI.id < 1 then
      thePI = User.new(
        :username =>  CleanLDAPvalue(pi_data["uid"]), 
        :last_name => CleanLDAPvalue(pi_data["sn"]),
        :middle_name => ((CleanLDAPvalue(pi_data["displayname"]).split(" ").length > 2) ? pi_data["displayname"].split(" ")[1] : pi_data["numiddlename"]),
        :first_name => CleanLDAPvalue(pi_data["givenName"]),
        :email => CleanLDAPvalue(pi_data["mail"])
        )
    end
  rescue ActiveRecord::RecordInvalid => error
    puts "BuildPIobject: raised an error for an investigator with the id of '#{pi_data.uid} with an error of #{error.inspect}"
    if thePI.nil? then # something bad happened
      puts "BuildPIobject: unable to find or insert investigator with the id of '#{pi_data.uid}"
      raise "BuildPIobject: unable to find or insert investigator with the id of  '#{pi_data.uid}"
    end
  end 
  thePI
end

def MergePIrecords(thePI, pi_data)
  # trust LDAP
  if ! pi_data.blank?
    thePI.title = CleanLDAPvalue(pi_data["title"]) || thePI.title
    thePI.business_phone = CleanLDAPvalue(pi_data["telephoneNumber"]) || thePI.business_phone
    thePI.employee_id = CleanLDAPvalue(pi_data["employeeNumber"]) || thePI.employee_id
    thePI.campus_address = CleanLDAPvalue(pi_data["postalAddress"]) || thePI.campus_address
    thePI.campus_address = thePI.campus_address.split("$").join(13.chr) if !  thePI.campus_address.blank?
    thePI.campus = CleanLDAPvalue(pi_data["postalAddress"]).split("$").last || thePI.campus if ! pi_data["postalAddress"].blank?
    # home_department is no longer a string
    thePI["primary_department"] = CleanLDAPvalue(pi_data.ou)  if pi_data.ou !~ /People/
    #trust the internal system first
    thePI.email ||= CleanLDAPvalue(pi_data["mail"])
    thePI.fax ||= CleanLDAPvalue(pi_data["facsimiletelephonenumber"])
    thePI = cleanup_campus(thePI)
  end
  thePI
end

def CleanPIfromLDAP(pi_data)
  if pi_data.length > 0 then
    clean_rec = CleanLDAPrecord(pi_data[0])
    clean_rec = AddToLDAPrecord(clean_rec, ["nuMiddleName","employeeNumber","sn","uid","givenName","title","telephoneNumber","postalAddress","mail","facsimiletelephonenumber"])
    clean_rec = AddToLDAPrecord(clean_rec, ["ou"], "" )
    return clean_rec
  end
  pi_data
end

def MakePIfromLDAP(pi_data)
  if pi_data.length > 0 then
    clean_rec = CleanPIfromLDAP(pi_data)
    thePI = BuildPIobject(clean_rec)
    thePI=MergePIrecords(thePI, clean_rec)
    begin
      logger.info "MakePIfromLDAP: #{thePI.id}  #{thePI.username} #{thePI.last_name} #{thePI.first_name}"
#      logger.info pi_data.inspect
#      logger.info thePI.inspect
    rescue Exception => error
      puts "#{thePI.id}  #{thePI.username} #{thePI.last_name} #{thePI.first_name}"
      puts pi_data.inspect
      puts thePI.inspect
    end
    return thePI
  end
end

# may need to adapt the ldap attributes to the Investigator data model
def CreateOrUpdatePI(thePI)
  puts "CreateOrUpdatePI: this shouldn't happen - thePI was nil" if thePI.nil?
  begin 
    thePI.save!
  rescue ActiveRecord::RecordInvalid => error
    puts "CreateOrUpdatePI: raised an error for an investigator with the id of '#{thePI.username} with an error of #{error.inspect}"
  end 
  thePI
end
