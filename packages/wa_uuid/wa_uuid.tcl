package provide wa_uuid 0.3

namespace eval wa_uuid {
	set types(unknown) 0

	# Name: ::uuid::gen
	# Args:
	#	?prefix?	Prefix of UUID (may be numeric or a type)
	# Rets: A UUID
	# Stat: Complete
	proc gen {{prefix 0}} {
		if {![string is integer -strict $prefix]} {
			if {[info exists ::wa_uuid::types($prefix)]} {
				set prefix $::wa_uuid::types($prefix)
			} else {
				set prefix 0
			}
		}
		expr srand(int((rand() * 32768) * $prefix) + [pid] + [info cmdcount])

		set uuid [format "%x-%x-%x-%x%x%x" $prefix [expr int(rand() * 2147483647)] [clock clicks] [clock seconds] [expr int(rand() * 2147483647)] [pid]]

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
			foreach {type prefixes} [array get ::wa_uuid::types] {
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

		lappend ::wa_uuid::types($type) $prefix

		if {$module != ""} {
			lappend ::wa_uuid::modules($prefix) $module
		}

		return 1
	}
}
