set init(session_switch) ""

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
		foreach dbkey [db::listkeys sessions] {
			set id [lindex $dbkey 0]
			set var [lindex $dbkey 1]

			if {$id != $sessionid} { continue }

			debug "Loading from session: $var"
			set ::request::session($var) [db::get sessions $dbkey]
		}
		set ::request::session(sessionid) $sessionid

		if {$updateargs} {
			set ::request::args(sessionid) $sessionid
		}

		cookie set sessionid $sessionid -minutes 10

		return 0
	}

	# No session specified, create one.
	set sessionid [db::getuuid 110]

	debug "Creating new session ($sessionid)"

	# Set a dummy variable so the array exists
	set ::request::session(sessionid) $sessionid
	db::set sessions [list $sessionid sessionid] $sessionid

	cookie set sessionid $sessionid -minutes 10

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
		foreach key [db::listkeys sessions] {
			set id [lindex $key 0]
			set var [lindex $key 1]

			if {$id != $sessionid} { continue }

			db::unset sessions $key
		}
		return 0
	}

	# Add or update new keys
	foreach var [array names ::request::session] {
		debug "Writing ::request::session($var)"
		db::set sessions [list $sessionid $var] $::request::session($var)
	}

	# Delete keys which no longer exist
	foreach key [db::listkeys sessions] {
		set id [lindex $key 0]
		set var [lindex $key 1]

		if {$id != $sessionid} { continue }

		if {![info exists ::request::session($var)]} {
			db::unset sessions $key
		}
	}

	return 0
}

proc session_terminate {} {
	unset -nocomplain ::request::args(sessionid) ::request::args(key) ::request::session
}
