#! /usr/bin/tclsh

lappend auto_path packages

package require user
package require db

source local/autoload/siteconfig.tcl
siteconfig start

db::create -dbname sessions -fields [list sessionid data]
db::create -dbname user -fields [list uid user name flags opts pass]

set uid [user::create -user rkeene -name "Roy Keene" -flags root -pass temporary]
if {$uid == 0} {
	set uid [lindex [user::listflag root] 0]
}
puts "rootuid = $uid"
