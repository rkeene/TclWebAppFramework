package provide module 0.1

package require user

namespace eval module {
	# Name: ::module::register
	# Args:
	#	module		Name of module
	#	flags		List of flags required to use module
	#	icon		Icon for module
	#	desc		Text description of module
	# Rets: 1 on success, 0 otherwise
	# Stat: Complete
	proc register {module flags icon desc} {
		set ret 0

		catch {
			set ret [${module}::init]
		}

		if {$ret} {
			set ::module::modinfo($module) [::list $flags $icon $desc]
		}

		return $ret
	}

	# Name: ::module::unregister
	# Args:
	#	modules		Modules to unregister
	# Rets: 1 on success, 0 otherwise
	# Stat: Complete
	proc unregister {modules} {
		set ret 1

		foreach module $modules {
			set check 1
			catch {
				set check [${module}::fini]
			}
			if {$check} {
				unset -nocomplain ::module::modinfo($module)
			} else {
				set ret 0
			}
		}

		return $ret
	}

	# Name: ::module::call
	# Args:
	#	module		Name of module to call
	#	?action?	Primary action to initiate
	#	?subaction?	Subaction
	#	?subaction?	...
	# Rets: A relative (without a / as the first char) path to a file to
	#	be `parse'd or an absolute (with a '/' as the first char)
	#	file to be parsed.
	# Stat: Complete
	proc call {module {action main} {subaction ""}} {
		if {![::info exists ::module::modinfo($module)]} {
			return ""
		}

		set requiredflags [lindex $::module::modinfo($module) 0]

		# Verify that the user specified has suffcient privileges to
		# use this module..
		if {![user::hasflag $requiredflags]} {
			return ""
		}

		if {$action == ""} {
			set action "main"
		}

		set ret [${module}::${action} $subaction]

		return $ret
	}

	# Name: ::module::list
	# Args:
	#	uid		UID to check for module accessibility.
	#			(note: A list of flags will also work
	#			because user::hasflag accepts this
	#			notation)
	# Rets: A list of modules which are available to users with `flags'
	#	In the form of: {module flags icon desc}
	# Stat: In progress
	proc list {{uid ""}} {
		set ret ""

		if {$uid == "-all"} {
			set allbool 1
		} else {
			set allbool 0
		}

		foreach {module modinfo} [array get ::module::modinfo] {
			set chkflags [lindex $modinfo 0]
			set icon [lindex $modinfo 1]
			set desc [lindex $modinfo 2]
			if {!$allbool && ![user::hasflag $chkflags $uid]} {
				continue
			}
			lappend ret [::list $module $chkflags $icon $desc]
		}

		return $ret
	}

	# Name: ::module::info
	# Args:
	#	modules		List of modules to return info on
	# Rets: A list containing the following list for each module:
	#	module flags icon desc
	# Stat: Complete
	proc info {modules} {
		set ret ""

		foreach module $modules {
			if {![::info exists ::module::modinfo($module)]} {
				lappend ret [list $module "" "" ""]
				continue
			}
			set flags [lindex $::module::modinfo($module) 0]
			set icon [lindex $::module::modinfo($module) 1]
			set desc [lindex $::module::modinfo($module) 2]
			lappend ret [list $module $flags $icon $desc]
		}

		return $ret
	}
}
