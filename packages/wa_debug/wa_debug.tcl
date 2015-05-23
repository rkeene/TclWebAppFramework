package provide wa_debug 1.0

namespace eval wa_debug {
	proc log {src msg} {
		if {![info exists ::wa_debug::logfile]} {
			return
		}

		catch {
			if {$::wa_debug::logfile == "-"} {
				set logfd stderr
			} else {
				set logfd [open $::wa_debug::logfile a+]
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
		set ::wa_debug::logfile $file
	}

	proc logoff {} {
		unset -nocomplain ::wa_debug::logfile
	}
}
