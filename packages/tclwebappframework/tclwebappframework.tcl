#! /usr/bin/env tclsh

namespace eval ::tclwebappframework {
	variable initmods [list]
	variable initmods_clean [list]

	proc register_initmod {module {priority ""}} {
		lappend ::tclwebappframework::initmods_clean $module
		unset -nocomplain ::tclwebappframework::finimods

		if {$priority != ""} {
			set module "${priority}:${module}"
		}

		lappend ::tclwebappframework::initmods $module
	}

	proc get_initmods {} {
		return $::tclwebappframework::initmods_clean
	}

	proc get_finimods {} {
		if {![info exists ::tclwebappframework::finimods]} {
			set ::tclwebappframework::finimods [lreverse $::tclwebappframework::initmods_clean]
		}

		return $::tclwebappframework::finimods
	}
}

package provide tclwebappframework 0.1
