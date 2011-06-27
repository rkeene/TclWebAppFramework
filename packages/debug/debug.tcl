package provide debug 1.0

namespace eval debug {
	proc log {src msg} {
		if {![info exists ::debug::logfile]} {
			return
		}

		catch {
			if {$::debug::logfile == "-"} {
				set logfd stderr
			} else {
				set logfd [open $::debug::logfile a+]
			}

			set usec [lindex [split [expr [format "%u" [clock clicks]].0 / 1000000.0] .] 1]

			append usec [string repeat "0" [expr {6 - [string length $usec]}]]

			puts $logfd "[clock seconds].$usec \[[pid]\]: \[$src\] => $msg"

			if {$logfd != "stderr"} {
				close $logfd
			}
		}
	}

	proc logfile {file} {
		set ::debug::logfile $file
	}

	proc logoff {} {
		unset -nocomplain ::debug::logfile
	}
}
