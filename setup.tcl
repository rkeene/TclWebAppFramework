#! /usr/bin/tclsh

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

package require user
package require db
package require module

if {[file exists modules/autoload/onlyonce/siteconfig.tcl]} {
	source modules/autoload/onlyonce/siteconfig.tcl
}
if {[file exists local/modules/autoload/onlyonce/siteconfig.tcl]} {
	source local/modules/autoload/onlyonce/siteconfig.tcl
}

namespace eval config {}

if {![info exists config::db(user)] || ![info exists config::db(pass)] || ![info exists config::db(server)] || ![info exists config::db(dbname)]} {
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

	set fd [open "local/modules/autoload/onlyonce/siteconfig.tcl" a+]
	puts $fd "namespace eval ::config {"
	puts $fd "	[list set db(user) $config::db(user)]"
	puts $fd "	[list set db(pass) $config::db(pass)]"
	puts $fd "	[list set db(server) $config::db(server)]"
	puts $fd "	[list set db(dbname) $config::db(dbname)]"
	puts $fd "	[list unset db(unconfigured)]"
	puts $fd "}"
	close $fd
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
