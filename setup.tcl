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

source modules/autoload/onlyonce/siteconfig.tcl
source local/modules/autoload/onlyonce/siteconfig.tcl

db::create -dbname sessions -fields [list sessionid data]
db::create -dbname user -fields [list uid user name flags opts pass]

set rootuid [user::create -user $rootuser -name "Administrator" -flags root -pass $rootpass]
set anonuid [user::create -user anonymous -name "Anonymous Web User"]
if {$rootuid == 0} {
	set rootuid [lindex [user::listflag root] 0]
	user::change -uid $rootuid -flags root -pass $rootpass
}
if {$anonuid == 0} {
	set anonuid [user::getuid anonymous]
}

set realrootuser [user::get -uid $rootuid -user]
set realanonuser [user::get -uid $anonuid -user]

puts "$realrootuser = $rootuid"
puts "$realanonuser = $anonuid"
