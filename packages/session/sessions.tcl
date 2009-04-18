package provide session 0.3

package require db
package require wa_uuid

wa_uuid::register 110 session

namespace eval session {
	# Name: ::session::_mark_for_writing
	# Args: var, idx, op
	# Rets: 1
	# Stat: In progress.
	proc _mark_for_writing {var idx op} {
		catch {
			debug::log session::__mark_for_writing "Session variable ($var) index \"$idx\" has been written or unset ($op) (from [string range [info level -1] 0 50])"
		}

		set ::session::vars_updated 1
		return 1
	}

	# Name: ::session::create
	# Args: (none)
	# Rets: The `sessionid' of the new session
	# Stat: In progress.
	proc create {} {
		unset -nocomplain ::session::vars ::session::id

		set sessionid [wa_uuid::gen session]

		set ::session::id $sessionid

		set ::session::vars(sessionid) $sessionid

		set ::session::vars_updated 1

		return $sessionid
	}

	# Name: ::session::load
	# Args:
	#	sessionid	SessionID to save to
	# Rets: 1 on success, 0 otherwise
	# Stat: In progress
	proc load {sessionid} {
		unset -nocomplain ::session::vars ::session::vars_updated

		set sessiondata [db::get -dbname sessions -where sessionid=$sessionid -field data]

		array set ::session::vars $sessiondata

		set ::session::id $sessionid

		trace add variable ::session::vars [list write unset] ::session::_mark_for_writing

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

		# If there have been no changes since the last "load", return
		# success.
		if {![info exists ::session::vars_updated]} {
			return 1
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

		set ::session::vars_updated 1

		return 1
	}
}
