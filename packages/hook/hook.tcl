package provide hook 0.1

namespace eval hook {
	# Name: ::hook::register
	# Args:
	#	id		Id to register callback
	#	callback	Procedure to call back
	# Rets: 1 on success, 0 otherwise
	# Stat: Complete
	proc register {id callback} {
		# Do not allow the same function to register itself
		# many times.
		if {[info exists ::hook::callbacks($id)]} {
			foreach chkcallback $::hook::callbacks($id) {
				if {$chkcallback == $callback} {
					return 1
				}
			}
		}

		lappend ::hook::callbacks($id) $callback

		return 1
	}

	# Name: ::hook::unregister
	# Args:
	#	?id?		Id of callback to unregister
	#	?callback?	Callback to unregister
	# Rets: 1 on success, 0 otherwise
	# Stat: Complete
	proc unregister {{id ""} {callback ""}} {
		if {$id == "" && $callback == ""} {
			unset -nocomplain ::hook::callbacks
			return 1
		}

		if {$callback == ""} {
			unset -nocomplain ::hook::callbacks($id)
			return 1
		}

		if {$id == ""} {
			set ret 1

			foreach {chkid chkcallback} [array get ::hook::callbacks] {
				set cbidx [lsearch -exact $chkcallback $callback]
				if {$cbidx != -1} {
					set chkret [unregister $chkid $callback]
					if {!$chkret} {
						set ret 0
					}
				}
			}

			return $ret
		}

		if {![info exists ::hook::callbacks($id)]} {
			return 1
		}

		set cbidx [lsearch -exact $::hook::callbacks($id) $callback]
		if {$cbidx != -1} {
			set cbidxlo [expr $cbidx - 1]
			set cbidxpo [expr $cbidx + 1]
			set newlista [lrange $::hook::callbacks($id) 0 $cbidxlo]
			set newlistb [lrange $::hook::callbacks($id) $cbidxpo end]
			set ::hook::callbacks($id) [join [list $newlista $newlistb]]
		}

		return 1
	}

	# Name: ::hook::call
	# Args:
	#	id		ID of callback to initiate
	#	val		Argument list to pass
	# Rets: Number of callbacks that handled this (0 if none)
	# Stat: Complete
	proc call args {

		set id [lindex $args 0]
		set val [lrange $args 1 end]
		set ret 0

		foreach chkid [array names ::hook::callbacks] {
			if {[string match $chkid $id]} {
				foreach callback $::hook::callbacks($chkid) {
					set chkret 0

					catch {
						set chkret [$callback $chkid $id $val]
					} errinfo

					if {$chkret} {
						incr ret
					}
				}
			}
		}

		return $ret
	}
}
