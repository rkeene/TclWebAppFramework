package provide debug 1.0

namespace eval debug {
	proc log {src msg} {
		catch {
			set logfd [open "/var/tmp/webapp-debug.log" a+]
			set usec [lindex [split [expr [format "%u" [clock clicks]].0 / 1000000.0] .] 1]
			puts $logfd "[clock seconds].$usec \[[pid]\]: \[$src\] => $msg"
			close $logfd
		}
	}
}
