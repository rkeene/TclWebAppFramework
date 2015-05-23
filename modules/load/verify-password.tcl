# Verify that the user and pass are correct if specified
# if they are, setup an authenticated session.
set uid ""
if {[user::getuid] == "0" && ![info exists args(user)]} {
	wa_debug::log "verify-password.tcl" "We are nobody, switching to the anonymous user."

	set uid [user::getuid "anonymous"]
} elseif {[info exists args(user)] && [info exists args(pass)]} {
	wa_debug::log "verify-password.tcl" "We have been asked to authenticate as a user ($args(user))"

	set newuid [user::getuid $args(user)]
	if {$newuid != "0"} {
		set user_ok [user::login $newuid $args(pass) "127.0.0.1"]

		if {$user_ok} {
			wa_debug::log "verify-password.tcl" "Password has been verified."

			set uid $newuid
		} else {
			wa_debug::log "verify-password.tcl" "Failed to verify password, trying to switch to an anonymous user"

			set uid [user::getuid "anonymous"]
		}
	} else {
		wa_debug::log "verify-password.tcl" "Invalid user \"$args(user)\", ignoring."
	}

	unset -nocomplain user_ok newuid
}

if {$uid != ""} {
	if {$uid != "0"} {
		set suidret [user::setuid $uid]

		wa_debug::log "verify-password.tcl" "Switching to UID $uid ([user::getnam $uid])... $suidret"
	} else {
		wa_debug::log "verify-password.tcl" "Unable to initiate user switching, cannot lookup uid for \"anonymous\""
	}

	unset -nocomplain uid suidret
}

unset -nocomplain args(pass) args(user)
