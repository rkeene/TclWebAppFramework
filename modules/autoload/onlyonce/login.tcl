package require web
package require user

namespace eval login {

	proc init {} {
		return 1
	}

	proc main args {
		if {![info exists ::login::anonymousuid]} {
			set ::login::anonymousuid [user::getuid anonymous]
		}
		set auth 0
		if {[info exists ::session::vars(uid)]} {
			if {$::session::vars(uid) != $::login::anonymousuid && $::session::vars(uid) != 0} {
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
