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
	set css(.icon) { border: 0; }
}

namespace eval ::config {
	set db(user) rkeene
	set db(pass) joe
	set db(server) localhost
	set db(dbname) rkeene
}
