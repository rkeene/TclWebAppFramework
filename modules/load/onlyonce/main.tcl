namespace eval main {
	proc init {} {
		# Must return 1 to complete registration.
		return 1
	}

	proc main args {
		return "pages/main.rvt"
	}
}

module::register main "" "" "The main page"
