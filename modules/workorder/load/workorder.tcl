namespace eval workordersend {
	proc init {} {
		return 1
	}
	proc main args {
		return "send.rvt"
	}
}

module::register workordersend [list workorder] workordersend.png "Send a Work Order"
