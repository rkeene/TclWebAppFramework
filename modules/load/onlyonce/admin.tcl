package require user
package require debug

namespace eval admin {
	proc init {} {
		return 1
	}

	proc main args {
		return "main.rvt"
	}

	proc new args {
		debug::log admin::new "args => $args"
		return "new.rvt"
	}
}

module::register admin [list admin] admin.png "User Administration"
