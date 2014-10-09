#! /usr/bin/env tclsh

package require web
package require tclwebappframework

namespace eval siteconfig {
	proc init {} {
		return 1
	}
	proc start args {
		return "style/header.rvt"
	}
	proc stop args {
		return "style/footer.rvt"
	}
}

if {[module::register siteconfig "" "" "Site graphical configuration" [list init start stop]]} {
	::tclwebappframework::register_initmod siteconfig
}

# Set default CSS
namespace eval ::html {
	variable css

	set css(a) { text-decoration: none; color: #FF0000; }
	set css(.icons) { border: 0; }
	set css(.module_error) { text-align: center; color: #FF0000; }
}
