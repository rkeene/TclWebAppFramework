namespace eval html {
	proc init {} {
		return 1
	}

	proc main args {
		return ""
	}

	proc start args {
		return "header.rvt"
	}

	proc stop args {
		return "footer.rvt"
	}
}

if {[module::register html "" "" "HTML Module"]} {
	lappend ::initmods "00:html"
}
