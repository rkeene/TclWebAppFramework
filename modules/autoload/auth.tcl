set init(auth_init) ""

proc auth_init {action} {
	# We only do startup.
	if {$action!="start"} { return 1 }

	package require db

	if {[info exists ::request::args(user)] && [info exists ::request::args(cookie)]} {
		# Verify user with cookie
		if {![auth_verifycookie $::request::args(user) $::request::args(cookie)]} {
			unset ::request::args(user)
			unset ::request::args(cookie)
			set ::request::module "login"
		}
	}

	if {[info exists ::request::args(user)] && [info exists ::request::args(pass)]} {
		# Verify user and unset args(pass)

		set user_ok [auth_verifypass $::request::args(user) $::request::args(pass)]
		if {[info exists ::request::args(submit)]} {
			unset ::request::args(submit)
		}

		if {$user_ok} {
			# Set ::request::args(cookie)
			set ::request::args(cookie) [auth_login $::request::args(user)]
		} else {
			unset ::request::args(user)
			set ::request::module "login"
		}
		unset ::request::args(pass)
	}

	if {[info exists ::request::args(user)] && ![info exists ::request::args(cookie)]} {
		unset ::request::args(user)
		set ::request::module "login"
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
