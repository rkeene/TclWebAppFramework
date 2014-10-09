#! /usr/bin/env tclsh

package require tclwebappframework

namespace eval html {
	proc init {} {
		return 1
	}

	proc main args {
		return ""
	}

	proc start args {
		return "header.rvt"
	}

	proc stop args {
		return "footer.rvt"
	}
}

# Register this module so we can be called
if {[module::register html "" "" "HTML Module" [list init start stop]]} {
	# Register this module as an initialization module
	::tclwebappframework::register_initmod html 00
}
