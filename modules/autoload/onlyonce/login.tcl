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

		set curruser [user::getuid]

		if {$curruser != 0} {
			if {$curruser != $::login::anonymousuid} {
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
