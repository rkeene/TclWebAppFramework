package require session

namespace eval logout {
	proc init {} {
		return 1
	}
	proc main args {
		set olduid $::session::vars(uid)
		session::destroy
		return "loggedout.rvt"
	}
}

module::register "logout" "" "logout" "Logout"
