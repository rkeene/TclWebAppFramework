namespace eval cal {
	proc init {} {
		return 1
	}
	proc main {subact} {
		return "main.rvt"
	}
}

module::register cal [list calendar] calendar "Calendar Creator"
