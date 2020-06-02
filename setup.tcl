#! /usr/bin/env tclsh

if {[lindex $argv 0] eq "--help"} {
	puts "usage: setup.tcl \[<args>\]"
	puts ""
	puts "args:"
	puts "    --db {mysql|sqlite|mk4}"
	puts "    --root-user <username>"
	puts "    --root-password <password>"
	puts ""
	puts "For --db mysql:"
	puts "    --mysql-username <username>"
	puts "    --mysql-password <password>"
	puts "    --mysql-host <hostname>"
	puts "    --mysql-dbname <database_name>"
	puts ""
	puts "For --db sqlite and --db mk4:"
	puts "    --db-file <filename>"
	puts "    --db-file-relative {y|n}"
	exit 0
}

array set cli_config $argv

cd [file dirname [info script]]

lappend auto_path packages

proc prompt {cli_config_option prompt variable {validate ""}} {
	if {![info exists ::cli_config($cli_config_option)]} {
		puts -nonewline "${prompt}: "
		flush stdout
		gets stdin value
	} else {
		set value $::cli_config($cli_config_option)
	}

	if {$validate ne ""} {
		set value [apply $validate $value]
	}

	uplevel 1 [list set $variable $value]
}

namespace eval ::config {}

prompt --db "Type of DB (mysql, mk4, sqlite)" config::db(mode) {{dbtype} {
	switch -- [string trim [string tolower $dbtype]] {
		"mysql" - "sql" - "" {
			set dbtype mysql
		}
		"mk4" {
			set dbtype mk4
		}
		"sqlite" {
			set dbtype sqlite
		}
	}
	return $dbtype
}}

package require user
package require db
package require module

if {[file exists modules/load/onlyonce/dbconfig.tcl]} {
	source modules/load/onlyonce/dbconfig.tcl
}
if {[file exists local/modules/load/onlyonce/dbconfig.tcl]} {
	source local/modules/load/onlyonce/dbconfig.tcl
}

namespace eval config {}

set rootuser ""
set rootpass ""
while 1 {
	prompt --root-user "Please enter a username for the initial user" rootuser
	prompt --root-password "Please enter a password" rootpass

	if {$rootpass != "" && $rootuser != ""} {
		break
	}

	puts stderr "Invalid!"
}

if {$config::db(mode) == "mysql"} {
	prompt --mysql-username "DB Username" config::db(user)
	prompt --mysql-password "DB Password" config::db(pass)
	prompt --mysql-host     "DB Host"   config::db(server)
	prompt --mysql-dbname   "DB Database Name" config::db(dbname)

	file mkdir "local/modules/load/onlyonce/"
	set fd [open "local/modules/load/onlyonce/dbconfig.tcl" w]
	puts $fd "namespace eval ::config {"
	puts $fd "	[list set db(user) $config::db(user)]"
	puts $fd "	[list set db(pass) $config::db(pass)]"
	puts $fd "	[list set db(server) $config::db(server)]"
	puts $fd "	[list set db(dbname) $config::db(dbname)]"
	puts $fd "	[list set db(mode) mysql]"
	puts $fd "}"
	close $fd
} else {
	prompt --db-file "DB Filename" config::db(filename)
	if {[string index $config::db(filename) 0] != "/"} {
		prompt --db-file-relative "Database relative to running script (y) or setup.tcl (n) (y/N)" relative {{value} {
			switch -exact -- [string tolower $value] {
				"y" - "yes" {
					set value true
				}
				default {
					set value false
				}
			}

			return $value
		}}
	} else {
		set relative false
	}

	file mkdir "local/modules/load/onlyonce/"
	set fd [open "local/modules/load/onlyonce/dbconfig.tcl" w]
	puts $fd "namespace eval ::config {"

	if {$relative} {
		puts stderr " *** SECURITY WARNING ***"
		puts stderr "Please ensure that the database file (\"$config::db(filename)\") is not"
		puts stderr "accessible via HTTP (this usually does not affect RivetCGI)."
		puts stderr " *** SECURITY WARNING ***"

		puts $fd "	if {\[info exists ::starkit::topdir\]} {"
		puts $fd "		set db(filename) \[file join \[file dirname \[file normalize \$::starkit::topdir\]\] [list $config::db(filename)]\]"
		puts $fd "	} else {"
		puts $fd "		set db(filename) \[file join \[file dirname \[info script\]\] [list $config::db(filename)]\]"
		puts $fd "	}"
	} else {
		set config::db(filename) [file normalize $config::db(filename)]

		puts $fd "	[list set db(filename) $config::db(filename)]"
	}

	puts $fd "	[list set db(mode) $config::db(mode)]"
	puts $fd "}"
	close $fd

	catch {
		file delete -force -- $config::db(filename)
	}
}

db::create -dbname sessions -fields [list sessionid data]
db::create -dbname user -fields [list uid user name flags opts pass]
db::create -dbname file -fields [list id name readperm writeperm]

set manrootuid [wa_uuid::gen user]
db::set -dbname user -field uid $manrootuid -field user "tmpuser_[clock seconds]" -field flags [list root] -field pass "*LK*"
user::setuid $manrootuid

set rootuid [user::create -user $rootuser -name "Administrator" -flags root -pass $rootpass]

if {$rootuid == 0} {
	set rootuid [user::getuid $rootuser]
	user::change -uid $rootuid -flags root -pass $rootpass
}
user::setuid $rootuid
user::delete $manrootuid

set anonuid [user::create -user anonymous -name "Anonymous Web User"]
if {$anonuid == 0} {
	set anonuid [user::getuid anonymous]
}

set realrootuser [user::get -uid $rootuid -user]
set realanonuser [user::get -uid $anonuid -user]

puts "$realrootuser = $rootuid"
puts "$realanonuser = $anonuid"

catch {
	update
}
