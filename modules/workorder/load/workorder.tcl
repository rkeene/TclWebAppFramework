namespace eval workorder {
	proc init {} {
		return 1
	}
	proc main args {
		return "send.rvt"
	}
}

module::register workorder [list workorder] workorder.png "Send a Work Order"
