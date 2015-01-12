# If we do not have a loaded session, load or create one
if {![info exists ::session::vars(sessionid)]} {
	# Get the session ID from a cookie
	set sessionid [cookie get sessionid]

	# Look for an argument to override the cookie value
	if {[info exists args(sessionid)]} {
		set sessionid $args(sessionid)
	}

	# Create or load the session
	if {$sessionid == ""} {
		# Create a new session
		set sessionid [session::create]

		# Set a cookie to hold the session ID
		cookie set sessionid $sessionid -minutes 720
	} else {
		# Load the session
		session::load $sessionid
	}

	unset -nocomplain sessionid
}
