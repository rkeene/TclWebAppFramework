namespace eval school {
	proc init {} {
		return 1
	}
	proc main args {
		if {[info exists ::request::args(school)]} {
			set school $::request::args(school)
		} else {
			set school main
		}
		if {[string match "*/*" $school]} {
			set school main
		}
		return "pages/$school.rvt"
	}
}

module::register school "" "" "School pages."
