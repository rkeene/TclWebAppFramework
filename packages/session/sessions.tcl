package require db
package require uuid

package provide session 0.3

uuid::register 110 session

namespace eval session {
	# Name: ::session::create
	# Args: (none)
	# Rets: The `sessionid' of the new session
	# Stat: In progress.
	proc create {} {
		unset -nocomplain ::session::vars ::session::id

		set sessionid [uuid::gen session]

		set ::session::id $sessionid

		set ::session::vars(sessionid) $sessionid

		return $sessionid
	}

	# Name: ::session::load
	# Args:
	#	sessionid	SessionID to save to
	# Rets: 1 on success, 0 otherwise
	# Stat: In progress
	proc load {sessionid} {
		unset -nocomplain ::session::vars

		foreach {var val} [db::get -dbname sessions -where sessionid=$sessionid -field data] {
			set ::session::vars($var) $val
		}

		set ::session::id $sessionid

		return 1
	}

	# Name: ::session::save
	# Args: (none)
	# Rets: 1 on success, 0 otherwise
	# Stat: In progress.
	proc save {} {
		if {![info exists ::session::id]} {
			return 0
		}

		set sessionid $::session::id

		if {[info exists ::session::vars]} {
			foreach {var val} [array get ::session::vars] {
				lappend newdata $var $val
			}

			set ret [db::set -dbname sessions -field sessionid $sessionid -field data $newdata]
		} else {
			set ret [db::unset -dbname sessions -where sessionid=$sessionid]
		}

		return $ret
	}

	# Name: ::session::destroy
	# Args: (none)
	# Rets: 1 on success, 0 otherwise
	# Stat: In progress.
	proc destroy {} {
		unset -nocomplain ::session::vars

		return 1
	}
}
