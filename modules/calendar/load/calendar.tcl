namespace eval cal {
	proc init {} {
		return 1
	}
}

module::register cal [list calendar] calendar "Calendar Creator"
