proc init_modules {} {
	global cmdlist module
	upvar #0 init init

	set addtoautopath [list packages]
	if {[lsearch $::auto_path "$addtoautopath"] == -1} {
		lappend ::auto_path $addtoautopath
	}

	foreach file [glob -nocomplain modules/autoload/*.tcl modules/*/autoload/*.tcl] {
		namespace eval ::request "source $file"
	}
	if {[info exists module]} {
		foreach file [glob -nocomplain modules/$module/onrequest/*.tcl local/$module/autoload/*.tcl] {
			namespace eval ::request "source $file"
		}
	}
	foreach file [glob -nocomplain local/modules/autoload/*.tcl local/autoload/*.tcl] {
		namespace eval ::request "source $file"
	}

	set cmddeplist ""

	# Primary initialization routines:
	foreach cmd [lsort -dictionary [array names init]] {
		set deplist [lindex $init($cmd) 0]
		set isdeplist [lindex $init($cmd) 1]
		foreach dep $deplist {
			lappend dependencies($cmd) $dep
		}
		foreach isdep $isdeplist {
			lappend dependencies($isdep) $cmd
		}
		lappend cmdlist $cmd
	}

	foreach cmddep [array names dependencies] {
		lappend cmddeplist [list $cmddep $dependencies($cmddep)]
	}

	if {[info exists cmdlist] && [info exists cmddeplist]} {
		set cmdlist [resolve_cmd_deps $cmdlist $cmddeplist]

		foreach cmd $cmdlist {
			set ret [$cmd start]
		}
	}

	return 1
}

proc de_init_modules {} {
	global cmdlist

	if {[info exists cmdlist]} {
		for {set idx [expr [llength $cmdlist]-1]} {$idx>=0} {incr idx -1} {
			set cmd [lindex $cmdlist $idx]
			set ret [$cmd stop]
		}
	}

	return 1
}

proc resolve_cmd_deps {cmdlist cmddeplist} {
	foreach cmd $cmdlist {
		set depidx [lsearch -glob $cmddeplist [list $cmd *]]
		if {$depidx==-1} { set deps "" } else { set deps [lindex [lindex $cmddeplist $depidx] 1] }
		foreach dep $deps {
			set depdeplist [resolve_cmd_deps $dep $cmddeplist]
			foreach depdep $depdeplist {
				lappend ret $depdep
			}
		}
		lappend ret $cmd
	}

	foreach item $ret {
		if {[info exists found($item)]} { continue }
		set found($item) 1
		lappend realret $item
	}

	return $realret
}
