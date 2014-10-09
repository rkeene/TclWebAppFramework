#! /usr/bin/env tclsh

namespace eval ::tclwebappframework {
	variable initmods [list]

	proc register_initmod {module {priority ""}} {
		if {$priority != ""} {
			set module "${priority}:${module}"
		}

		lappend ::tclwebappframework::initmods $module
	}

	proc get_initmods {} {
	}

	proc get_finimods {} {
	}
}

package provide tclwebappframework 0.1
