package require web
package require user

namespace eval login {
	set anonymousuid [user::getuid anonymous]

	proc init {} {
		return 1
	}

	proc main args {
		set auth 0
		if {[info exists ::session::vars(uid)]} {
			if {$::session::vars(uid) != $::login::anonymousuid} {
				set auth 1
			}
		}

		if {$auth} {
			return "pages/user.rvt"
		}

		return "pages/login.rvt"
	}
}

module::register login "" "" "Login module"
