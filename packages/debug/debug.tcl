package provide debug 1.0

namespace eval debug {
	proc log {src msg} {
		if {![info exists ::debug::logfile]} {
		}

		catch {
			set logfd [open $::debug::logfile a+]
			set usec [lindex [split [expr [format "%u" [clock clicks]].0 / 1000000.0] .] 1]
			puts $logfd "[clock seconds].$usec \[[pid]\]: \[$src\] => $msg"
			close $logfd
		}
	}

	proc logfile {file} {
		set ::debug::logfile $file
	}

	proc logoff {} {
		unset -nocomplain ::debug::logfile
	}
}
