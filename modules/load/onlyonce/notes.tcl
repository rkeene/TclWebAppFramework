package require user

namespace eval notes {
	proc init {} {
		return 1
	}

	proc main args {
		return "main.rvt"
	}

	proc new args {
		return "new.rvt"
	}
}

module::register notes [list notes] notes.png "Notes / e-Mail"
