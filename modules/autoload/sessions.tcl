set init(session_switch) "siteconfig"

proc session_switch {action} {
	package require db

	switch -- $action {
		"start" {
			return [session_load]
		}
		"stop" {
			return [session_save]
		}
	}

	return 1
}

proc session_load {} {
	# Load a session if it exists.
	set updateargs 0
	set sessionid [cookie get sessionid]
	if {[info exists ::request::args(sessionid)]} {
		set sessionid $::request::args(sessionid)
		set updateargs 1
	}
	if {$sessionid != ""} {
		debug "Loading session ($sessionid)"

		# Restore session data
		foreach {var val} [lindex [db::get -dbname sessions -fields data -where sessionid=$sessionid] 0] {
			debug "Loading from session: $var"
			set ::request::session($var) $val
		}
		set ::request::session(sessionid) $sessionid

		if {$updateargs} {
			set ::request::args(sessionid) $sessionid
		} else {
			cookie set sessionid $sessionid -minutes 720
		}

		return 0
	}

	# No session specified, create one.
	set sessionid [::db::genuuid 110]

	debug "Creating new session ($sessionid)"

	# Set a dummy variable so the array exists
	set ::request::session(sessionid) $sessionid

	db::set -dbname sessions -field sessionid $sessionid

	cookie set sessionid $sessionid -minutes 720

	return 0
}

proc session_save {} {
	# Verify that a session exists
	set sessionid [cookie get sessionid]
	if {[info exists ::request::args(sessionid)]} {
		set sessionid $::request::args(sessionid)
		set updateargs 1
	}
	if {[info exists ::request::session(sessionid)]} {
		set sessionid $::request::session(sessionid)
	}
	if {$sessionid == ""} {
		debug "No session in progress."
		return 1
	}

	# If the array gets deleted, delete everything from the database
	if {![array exists ::request::session]} {
		debug "Session has been terminated."
		db::unset -dbname sessions -where sessionid=$sessionid
		return 0
	}

	foreach var [array names ::request::session] {
		debug "Saving session variable: $var"
		set val $::request::session($var)
		lappend newdata $var $val
	}
	if {![info exists newdata]} {
		set newdata ""
	}
	db::set -dbname sessions -field sessionid $sessionid -field data $newdata

	return 0
}

proc session_terminate {} {
	unset -nocomplain ::request::args(sessionid) ::request::session
}
