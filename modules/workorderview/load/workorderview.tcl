namespace eval workorderview {
	proc init {} {
		return 1
	}
	proc main {subact} {
		return "main.rvt"
	}
}

module::register workorderview [list workorderview] workorderview "Work Order Manager"
