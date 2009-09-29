##
# This file is part of the Metasploit Framework and may be subject to
# redistribution and commercial restrictions. Please see the Metasploit
# Framework web site for more information on licensing and terms of use.
# http://metasploit.com/projects/Framework/
##

require 'msf/core'

class Metasploit3 < Msf::Auxiliary
        include Msf::Auxiliary::Report
	include Msf::Exploit::ORACLE
	
	def initialize(info = {})
		super(update_info(info,
                                'Name'           => 'Simple Oracle Database Enumeration.',
                                'Description'    => %q{
					This module allows for simple Oracle Databse Enumeration of parameters
                    that might be of importance during a Pentest. DBA Credentials must be 
					used.
                                },
                                'Author'         => [ 'Carlos Perez <carlos_perez [at] darkoperator [dot] com>' ],
                                'License'        => MSF_LICENSE,
                                'Version'        => '$Revision$',
                                'References'     =>
                                  [
					[ 'URL', 'http://www.darkoperator.com' ],
				]))

	end
		def plsql_query(exec)
                        querydata = ""
			begin
				sploit = connect.prepare(exec)
				sploit.execute
			rescue DBI::DatabaseError => e
                                raise e.to_s
                                #print_status("\t#{e.to_s}")
				return
			end

			begin
				sploit.each do | data |
				querydata << ("#{data.join(",").to_s} \n")
			end
				sploit.finish
			rescue DBI::DatabaseError => e
				#print_error("#{e.to_s}")
				if ( e.to_s =~ /ORA-24374: define not done before fetch or execute and fetch/ )
					print_status("Done...")
				else
					return
				end
			end
                        return querydata
		end

	def run
                begin
                        #Get all values from v$parameter
                        query = 'select name,value from v$parameter'
                        vparm = {}
                        params = plsql_query(query)
                        params.each_line do |l|
                                name,value = l.split(",")
                                vparm["#{name}"] = value
                        end

                end

		begin
                        print_status("Running Oracle Enumeration....")
                        #Version Check
                        query =  'select * from v$version'
			ver = plsql_query(query)
                        print_status("The versions of the Components are:")
                        ver.each_line do |v|
                                print_status("\t#{v.chomp}")
                                report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Component Version: #{v.chomp}")
                        end
                        #Saving Major Release Number for other checks
                        majorrel = ver.scan(/Edition Release (\d*)./)
                        
                        #-------------------------------------------------------
                        #Audit Check
                        print_status("Auditing:")
                        begin
                                if vparm["audit_trail"] == "NONE"
                                        print_status("\tDatabase Auditing is not enabled!")
                                        report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Audit Trail: Disabled")
                                else
                                        print_status("\tDatabase Auditing is enabled!")
                                        report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Audit Trail: Enabled")
                                end
           
                                if vparm["audit_sys_operations"] == "FALSE"
                                        print_status("\tAuditing of SYS Operations is not enabled!")
                                        report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Audit SYS Ops: Disabled")
                                else
                                        print_status("\tAuditing of SYS Operations is enabled!")
                                        report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Audit SYS Ops: Enabled")
                                end
                                           
                        end
                        #-------------------------------------------------------
                        #Security Settings
                        print_status("Security Settings:")
                        begin
                        
                                if vparm["sql92_security"] == "FALSE"
                                        print_status("\tSQL92 Security restriction on SELECT is not Enabled")
                                        report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "SQL92: Disabled")
                                else
                                        print_status("\tSQL92 Security restriction on SELECT is Enabled")
                                        report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "SQL92: Enabled")
                                end
                                
                     
                        #check for encryption of logins on version before 10g
                    
                                if majorrel.join.to_i < 10
                  
                                        if vparm["dblink_encrypt_login"] == "FALSE"
                                                print_status("\tLink Encryption for Logins is not Enabled")
                                                report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Link Encryption: Disabled")
                                        else
                                                print_status("\tLink Encryption for Logins is Enabled")
                                                report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Link Encryption: Enabled")
                                        end
                                end
                                
                                print_status("\tUTL Directory Access is set to #{utl.chomp}") if vparm["utl_file_dir"] != " "
                                report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "UTL_DIR: #{ vparm["utl_file_dir"]}") if not  vparm["utl_file_dir"].empty?
                                
                                print_status("\tAudit log is saved at #{vparm["audit_file_dest"]}")
                                report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Audit Log Location: #{ vparm["audit_file_dest"]}") if not  vparm["audit_file_dest"].empty?
                                
                        rescue
                                
                        end
                        #-------------------------------------------------------
                        #Password Policy
                        print_status("Password Policy:")
                        begin
                                query = %Q|
                                SELECT limit
                                FROM dba_profiles
                                WHERE resource_name = 'PASSWORD_LOCK_TIME'
                                AND profile         = 'DEFAULT'
                                |
                                lockout = plsql_query(query)
                                print_status("\tCurrent Account Lockout Time is set to #{lockout.chomp}")
                                 report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Account Lockout Time: #{lockout.chomp}")
                                
                        rescue => e
                                if e.to_s =~ /ORA-00942: table or view does not exist/
                                        print_error("It appears you do not have sufficient rights to perform the check")
                                end
                                
                        end
                        begin
                                query = %Q|
                                SELECT limit
                                FROM dba_profiles
                                WHERE resource_name = 'FAILED_LOGIN_ATTEMPTS'
                                AND profile         = 'DEFAULT'
                                |
                                failed_logins = plsql_query(query)
                                print_status("\tThe Number of Failed Logins before an account is locked is set to #{failed_logins.chomp}")
                                report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Account Fail Logins Permitted: #{failed_logins.chomp}")
                                
                        rescue => e
                                if e.to_s =~ /ORA-00942: table or view does not exist/
                                        print_error("It appears you do not have sufficient rights to perform the check")
                                end
                                
                        end
                        begin
                                query = %Q|
                                SELECT limit
                                FROM dba_profiles
                                WHERE resource_name = 'FAILED_LOGIN_ATTEMPTS'
                                AND profile         = 'DEFAULT'
                                |
                                grace_time = plsql_query(query)
                                print_status("\tThe Password Grace Time is set to #{grace_time.chomp}")
                                report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Account Password Grace Time: #{grace_time.chomp}")
                                
                        rescue => e
                                if e.to_s =~ /ORA-00942: table or view does not exist/
                                        print_error("It appears you do not have sufficient rights to perform the check")
                                end
                                
                        end
                        begin
                                query = %Q|
                                SELECT limit
                                FROM dba_profiles
                                WHERE resource_name = 'PASSWORD_LIFE_TIME'
                                AND profile         = 'DEFAULT'
                                |
                                passlife_time = plsql_query(query)
                                print_status("\tThe Lifetime of Passwords is set to #{passlife_time.chomp}")
                                report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Password Life Time: #{passlife_time.chomp}")
                                
                        rescue => e
                                if e.to_s =~ /ORA-00942: table or view does not exist/
                                        print_error("It appears you do not have sufficient rights to perform the check")
                                end
                                
                        end
                        begin
                                query = %Q|
                                SELECT limit
                                FROM dba_profiles
                                WHERE resource_name = 'PASSWORD_REUSE_TIME'
                                AND profile         = 'DEFAULT'
                                |
                                passreuse = plsql_query(query)
                                print_status("\tThe Number of Times a Password can be reused is set to #{passreuse.chomp}")
                                report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Password Reuse Time: #{passreuse.chomp}")
                                
                        rescue => e
                                if e.to_s =~ /ORA-00942: table or view does not exist/
                                        print_error("It appears you do not have sufficient rights to perform the check")
                                end
                                
                        end
                        begin
                                query = %Q|
                                SELECT limit
                                FROM dba_profiles
                                WHERE resource_name = 'PASSWORD_REUSE_MAX'
                                AND profile         = 'DEFAULT'
                                |
                                passreusemax = plsql_query(query)
                                print_status("\tThe Maximun Number of Times a Password needs to be changed before it can be reused is set to #{passreusemax.chomp}")
                                report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Password Maximun Reuse Time: #{passreusemax.chomp}")
                                print_status("\tThe Number of Times a Password can be reused is set to #{passreuse.chomp}")
                                
                        rescue => e
                                if e.to_s =~ /ORA-00942: table or view does not exist/
                                        print_error("It appears you do not have sufficient rights to perform the check")
                                end
                                
                        end
                        begin
                                query = %Q|
                                SELECT limit
                                FROM dba_profiles
                                WHERE resource_name = 'PASSWORD_VERIFY_FUNCTION'
                                AND profile         = 'DEFAULT'
                                |
                                passrand = plsql_query(query)
                                if passrand =~ /NULL/
                                        print_status("\tPassword Complexity is not checked")
                                        report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Password Complexity is not being checked for new passwords")
                                else
                                        print_status("\tPassword Complexity is being checked")
                                        report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Password Complexity is being checked for new passwords")
                                end
                                
                        rescue => e
                                if e.to_s =~ /ORA-00942: table or view does not exist/
                                        print_error("It appears you do not have sufficient rights to perform the check")
                                end
                                
                        end
                        #-------------------------------------------------------
                        begin
                                
                                if majorrel.join.to_i < 11
                                       
                                        query = %Q|
                                SELECT name, password 
                                FROM sys.user$
                                where password != 'null' and  type# = 1 and astatus = 0
                                        |
                                        activeacc = plsql_query(query)
                                        print_status("Active Accounts on the System in format Username,Hash are:")
                                        activeacc.each_line do |aa|
                                                print_status("\t#{aa.chomp}")
                                                report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Active Account #{aa.chomp}")
                                        end
                                else
                                        query = %Q|
                                        SELECT name, password, spare4
                                        FROM sys.user$
                                        where password != 'null' and  type# = 1 and astatus = 0
                                        |
                                        activeacc = plsql_query(query)
                                        print_status("Active Accounts on the System in format Username,Password,Spare4 are:")
                                        activeacc.each_line do |aa|
                                                print_status("\t#{aa.chomp}")
                                                report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Active Account #{aa.chomp}")
                                        end
                                end
                                
                        rescue => e
                                if e.to_s =~ /ORA-00942: table or view does not exist/
                                        print_error("It appears you do not have sufficient rights to perform the check")
                                        
                                end
                        end
                        begin
                                if majorrel.join.to_i < 11
                                        query = %Q|
                                SELECT username, password 
                                FROM dba_users
                                WHERE account_status = 'EXPIRED & LOCKED'
                                        |
                                        disabledacc = plsql_query(query)
                                        print_status("Expired or Locked Accounts on the System in format Username,Hash are:")
                                        disabledacc.each_line do |da|
                                                print_status("\t#{da.chomp}")
                                                report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Disabled Account #{da.chomp}")
                                        end
                                else
                                        query = %Q|
                                SELECT name, password, spare4
                                        FROM sys.user$
                                        where password != 'null' and  type# = 1 and astatus = 8 or astatus = 9
                                        |
                                        disabledacc = plsql_query(query)
                                        print_status("Expired or Locked Accounts on the System in format Username,Password,Spare4 are:")
                                        disabledacc.each_line do |da|
                                                print_status("\t#{da.chomp}")
                                                report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Disabled Account #{da.chomp}")
                                        end
                                end
                                
                        rescue => e
                                if e.to_s =~ /ORA-00942: table or view does not exist/
                                        print_error("It appears you do not have sufficient rights to perform the check")
                                end
                        end
                        begin
                                query = %Q|
                                SELECT grantee
                                FROM dba_role_privs
                                WHERE granted_role = 'DBA'
                                |
                                dbaacc = plsql_query(query)
                                print_status("Accounts with DBA Privilege  in format Username,Hash on the System are:")
                                dbaacc.each_line do |dba|
                                        print_status("\t#{dba.chomp}")
                                        report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Account with DBA Priv  #{dba.chomp}")
                                end
                                
                        rescue => e
                                if e.to_s =~ /ORA-00942: table or view does not exist/
                                        print_error("It appears you do not have sufficient rights to perform the check")
                                end
                        end
                        begin
                                query = %Q|
                                SELECT grantee
                                FROM dba_sys_privs
                                WHERE privilege = 'ALTER SYSTEM'
                                |
                                altersys = plsql_query(query)
                                print_status("Accounts with Alter System Privilege on the System are:")
                                altersys.each_line do |as|
                                        print_status("\t#{as.chomp}")
                                        report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Account with ALTER SYSTEM Priv  #{as.chomp}")
                                end
                                
                        rescue => e
                                if e.to_s =~ /ORA-00942: table or view does not exist/
                                        print_error("It appears you do not have sufficient rights to perform the check")
                                end
                        end
                        begin
                                query = %Q|
                                SELECT grantee
                                FROM dba_sys_privs
                                WHERE privilege = 'JAVA ADMIN'
                                |
                                javaacc = plsql_query(query)
                                print_status("Accounts with JAVA ADMIN Privilege on the System are:")
                                javaacc.each_line do |j|
                                        print_status("\t#{j.chomp}")
                                        report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Account with JAVA ADMIN Priv  #{j.chomp}")
                                end
                                
                        rescue => e
                                if e.to_s =~ /ORA-00942: table or view does not exist/
                                        print_error("It appears you do not have sufficient rights to perform the check")
                                end
                        end

                        begin
                                query = %Q|
                                select grantee
                                from dba_sys_privs
                                where privilege = 'CREATE LIBRARY'
                                or privilege = 'CREATE ANY'
                                |
                                libpriv = plsql_query(query)
                                print_status("Accounts that have CREATE LIBRARY Privilege on the System are:")
                                libpriv.each_line do |lp|
                                        print_status("\t#{lp.chomp}")
                                        report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Account with CREATE LIBRARY Priv  #{lp.chomp}")
                                end
                                
                        rescue => e
                                if e.to_s =~ /ORA-00942: table or view does not exist/
                                        print_error("It appears you do not have sufficient rights to perform the check")
                                end
                        end
                        #Default Password Check
                        begin
                                print_status("Default password check:")
                                if majorrel.join.to_i == 11
                                        query = %Q|
                                        SELECT * FROM dba_users_with_defpwd
                                        |
                                        defpwd = plsql_query(query)
                                        defpwd.each do |dp|
                                                print_status("\tThe account #{dp.chomp} has a default password.")
                                                 report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Account with Default Password #{dp.chomp}")
                                        end

                                else
                                        query = %Q|
                                SELECT name, password
                                FROM sys.user$
                                where password != 'null' and  type# = 1
                                        |
                                        ordfltpss = "#{File.join(Msf::Config.install_root, "data", "wordlists", "oracle_default_hashes.txt")}"
                                        returnedstring = plsql_query(query)
                                        accts = {}
                                        returnedstring.each_line do |record|
                                                user,pass = record.split(",")
                                                accts["#{pass.chomp}"] = "#{user}"
                                        end
                                        ::File.open(ordfltpss, "r").each_line do  |l|
                                                accrcrd =  l.split(",")
                                                if accts.has_key?(accrcrd[2])
                                                        print_status("\tDefault pass for account #{accrcrd[0]} is #{accrcrd[1]} ")
                                                        report_note(:host => datastore['RHOST'], :proto => 'TNS', :port => datastore['RPORT'], :type => 'ORA_ENUM', :data => "Account with Default Password #{accrcrd[0]} is #{accrcrd[1]}")
                                                end
                                        end

                                end
                        end
                        
                rescue ::Interrupt
                        raise $!
                end
        end

end
