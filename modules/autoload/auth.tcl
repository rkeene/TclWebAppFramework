set init(auth_init) [list session_switch ""] 

proc auth_init {action} {
	# We only do startup.
	if {$action!="start"} { return 1 }

	package require db
	package require user

	# Verify that the user and pass are correct if specified
	# if they are, setup an authenticated session.
	if {[info exists ::request::args(user)] && [info exists ::request::args(pass)]} {
		set user_ok [auth_verifypass $::request::args(user) $::request::args(pass)]
		set uid [user::getuid $::request::args(user)]

		if {$user_ok && $uid != -1} {
			set ::request::session(user) $::request::args(user)
			set ::request::session(uid) $uid
		} else {
			unset -nocomplain ::request::session(user)
			unset -nocomplain ::request::session(uid)
			unset -nocomplain ::request::args(user)
			unset -nocomplain ::request::args(pass)
			set ::request::module "login"
		}

		unset -nocomplain ::request::args(pass)
		unset -nocomplain ::request::args(user)
		unset -nocomplain ::request::args(submit)
	}

	return 1
}

proc auth_verifypass {user pass} {
	return 1
}

proc auth_verifycookie {user cookie} {
	return 1
}

proc auth_login {user} {
	return "JOE"
}
