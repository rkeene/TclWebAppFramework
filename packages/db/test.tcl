#! /usr/bin/env tclsh

lappend auto_path [file join [file dirname [info script]] ..]

namespace eval ::db {}
namespace eval ::config {}

set ::db::mode [lindex $argv 0]

switch -- $::db::mode {
	"mysql" {
		error "Not implemented"
	}
	"mk4" {
		set ::config::db(filename) "test.mk4"

		file delete -force -- test.mk4
	}
	"sqlite" {
		set ::config::db(filename) "test.sqlite"

		file delete -force -- test.sqlite
	}
}

package require db
package require debug

debug::logfile "-"

db::create -dbname test -fields [list joe:pk bob:u sally]

set ret [db::get -dbname test -field sally -where "joe=33"]
if {$ret != ""} {
	error "Returned: \"$ret\"; Expected \"\""
}

db::set -dbname test -field joe 33 -field sally "Little Lamb"
set ret [db::get -dbname test -field sally -where "joe=33"]
if {$ret != "Little Lamb"} {
	error "Returned: \"$ret\"; Expected \"Little Lamb\""
}

db::set -dbname test -field joe 33 -field sally "White as Snow"
set ret [db::get -dbname test -field sally -where "joe=33"]
if {$ret != "White as Snow"} {
	error "Returned: \"$ret\"; Expected \"White as Snow\" (1)"
}

set ret [db::get -dbname test -fields [list sally] -where "joe=33"]
if {[lindex $ret 0] != "White as Snow"} {
	error "Returned: \"$ret\"; Expected \"White as Snow\" (2)"
}

set ret [db::get -dbname test -field sally]
if {[lindex $ret 0 0] != "White as Snow"} {
	error "Returned: \"$ret\"; Expected \"White as Snow\" (3)"
}

set ret [db::get -dbname test -fields [list joe sally]]
if {[lindex $ret 0] != [list 33 "White as Snow"]} {
	error "Returned: \"$ret\"; Expected \"[list 33 "White as Snow"]\""
}

db::set -dbname test -field joe 32 -field sally 1


db::set -dbname test -field sally 2 -where "joe=32"

db::unset -dbname test -fields [list sally] -where "joe=32"

db::unset -dbname test -where "joe=32"

puts [db::get -dbname test -fields [db::fields -dbname test] -where "joe=32"]
puts [db::get -dbname test -fields [db::fields -dbname test] -where "joe=33"]

puts [db::fields -dbname test]
