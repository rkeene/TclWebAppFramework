package provide uuid 0.3

if {[catch {
	package require Tclx
}]} {
	package require Tclx-compat
}

namespace eval uuid {
	set types(unknown) 0

	# Name: ::uuid::gen
	# Args:
	#	?prefix?	Prefix of UUID (may be numeric or a type)
	# Rets: A UUID
	# Stat: Complete
	proc gen {{prefix 0}} {
		if {![string is integer -strict $prefix]} {
			if {[info exists ::uuid::types($prefix)]} {
				set prefix $::uuid::types($prefix)
			} else {
				set prefix 0
			}
		}
		random seed [expr [random 32768] * $prefix + [pid] + [info cmdcount]]

		set uuid [format "%x-%x-%x-%x%x" $prefix [random 2147483647] [random 2147483647] [random 2147483647] [pid]]

		return $uuid
	}

	# Name: ::uuid::type
	# Args:
	#	uuid		UUID to return the type of
	# Rets: A type based on the UUID prefix, "unknown" on error
	# Stat: Complete
	proc type {uuid} {
		set ret ""

		catch {
			set prefix [expr 0x[lindex [split $uuid -] 0]]
		}

		if {[info exists prefix]} {
			foreach {type prefixes} [array get ::uuid::types] {
				if {[lsearch $prefixes $prefix] != -1} {
					lappend ret $type
				}
			}
		}

		if {$ret == ""} {
			set ret "unknown"
		}

		return $ret
	}

	# Name: ::uuid::register
	# Args:
	#	prefix		Prefix to register name for
	#	type		Name to register
	#	?module?	What module handles this type
	# Rets: 1 if successful, 0 otherwise
	# Stat: Complete
	proc register {prefix type {module ""}} {
		if {![string is integer -strict $prefix]} {
			return 0
		}

		set existing [type "$prefix-0"]

		if {$existing != "unknown" && $existing != ""} {
			return 0
		}

		lappend ::uuid::types($type) $prefix

		if {$module != ""} {
			lappend ::uuid::modules($prefix) $module
		}

		return 1
	}
}