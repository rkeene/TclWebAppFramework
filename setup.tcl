#! /usr/bin/tclsh

cd [file dirname [info script]]

lappend auto_path packages

puts -nonewline "Type of DB (mysql, mk4, sqlite): "
flush stdout
gets stdin dbtype
namespace eval ::config {}
switch -- [string trim [string tolower $dbtype]] {
	"mysql" - "sql" - "" {
		set config::db(mode) mysql
	}
	"mk4" {
		set config::db(mode) mk4
	}
	"sqlite" {
		set config::db(mode) sqlite
	}
}

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
	puts -nonewline "Please enter a username: "
	flush stdout
	gets stdin rootuser

	puts -nonewline "Please enter a password: "
	flush stdout
	gets stdin rootpass
	if {$rootpass != "" && $rootuser != ""} {
		break
	}

	puts stderr "Invalid!"
}

if {$config::db(mode) == "mysql"} {
	puts -nonewline "DB Username: "
	flush stdout
	gets stdin config::db(user)

	puts -nonewline "DB Password: "
	flush stdout
	gets stdin config::db(pass)

	puts -nonewline "DB Host: "
	flush stdout
	gets stdin config::db(server)

	puts -nonewline "DB Database Name: "
	flush stdout
	gets stdin config::db(dbname)

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
	puts -nonewline "DB Filename: "
	flush stdout
	gets stdin config::db(filename)

	if {[string index $config::db(filename) 0] != "/"} {
		puts -nonewline "Database relative to index.rvt (Normal) or executable (Starkit) (y/N): "
		flush stdout
		gets stdin relative
	} else {
		set relative "n"
	}


	file mkdir "local/modules/load/onlyonce/"
	set fd [open "local/modules/load/onlyonce/dbconfig.tcl" w]
	puts $fd "namespace eval ::config {"

	if {[string tolower $relative] == "y"} {
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
