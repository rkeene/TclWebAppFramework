package require web

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

if {[module::register siteconfig "" "" "Site graphical configuration"]} {
	lappend ::initmods siteconfig
}

namespace eval ::html {
	set css(a) { text-decoration: none; color: #FF0000; }
	set css(.icons) { border: 0; }
	set css(.module_error) { text-alignment: center; color: #FF0000; }
}
