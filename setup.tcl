#! /usr/bin/tclsh

cd [file dirname [info script]]

lappend auto_path packages

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

puts -nonewline "Type of DB (mysql, mk4): "
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
}

package require user
package require db
package require module

if {[file exists modules/autoload/onlyonce/dbconfig.tcl]} {
	source modules/autoload/onlyonce/dbconfig.tcl
}
if {[file exists local/modules/autoload/onlyonce/dbconfig.tcl]} {
	source local/modules/autoload/onlyonce/dbconfig.tcl
}

namespace eval config {}

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

	file mkdir "local/modules/autoload/onlyonce/"
	set fd [open "local/modules/autoload/onlyonce/dbconfig.tcl" w]
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

	file mkdir "local/modules/autoload/onlyonce/"
	set fd [open "local/modules/autoload/onlyonce/dbconfig.tcl" w]
	puts $fd "namespace eval ::config {"
	puts $fd "	[list set db(filename) $config::db(filename)]"
	puts $fd "	[list set db(mode) mk4]"
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
db::set -dbname user -field uid $manrootuid -field user root -field flags [list root] -field pass "*LK*"
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
