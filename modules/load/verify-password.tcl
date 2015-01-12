# Verify that the user and pass are correct if specified
# if they are, setup an authenticated session.
if {[user::getuid] == "0" || [info exists args(user)]} {
	if {[info exists args(user)]} {
		set user_ok 0
		set uid 0

		if {![info exists args(pass)]} {
			unset -nocomplain args(user)
		} else {
			set uid [user::getuid $args(user)]
			set user_ok [user::login $uid $args(pass) "127.0.0.1"]
		}
	} else {
		set user_ok 1
		set uid [user::getuid anonymous]
		set args(user) anonymous
	}

	if {$user_ok && $uid != "0"} {
		set ::session::vars(user) $args(user)
		set suidret [user::setuid $uid]

		debug::log sessions.tcl "Switching to UID $uid... $suidret"
		
	} else {
		unset -nocomplain ::session::vars(user)
		user::setuid [user::getuid anonymous]
		unset -nocomplain args(user)
		unset -nocomplain args(pass)
	}

	unset -nocomplain args(pass)
	unset -nocomplain args(user)
	unset -nocomplain args(submit)
	unset -nocomplain uid user_ok
}
