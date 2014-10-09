package provide module 0.3

package require user
package require debug

namespace eval module {
	# Name: ::module::register
	# Args:
	#	module		Name of module
	#	flags		List of flags required to use module
	#	icon		Icon for module
	#	desc		Text description of module
	# Rets: 1 on success, 0 otherwise
	# Stat: Complete
	proc register {module flags icon desc {exposedactions ""}} {
		set ret 0

		catch {
			set ret [${module}::init]
		}

		if {$ret} {
			debug::log module::register "Registering module $module (ret = $ret)"

			set ::module::modinfo($module) [::list $flags $icon $desc $exposedactions]
		} else {
			debug::log module::register "Failed to register module $module (ret = $ret)"
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
		# Do not call modules that don't exist
		if {![::info exists ::module::modinfo($module)]} {
			return ""
		}

		# Use a default action
		if {$action == ""} {
			set action "main"
		}

		# Verify that the user specified has suffcient privileges to
		# use this module..
		set requiredflags [lindex $::module::modinfo($module) 0]
		if {![user::hasflag $requiredflags]} {
			return ""
		}

		# Verify that this is a public action
		## Exclude actions which start with an underscore or contain a namespace seperator
		if {[string index $action 0] == "_" || [string match "*::*" $action]} {
			return ""
		}

		## If the module enumerates its actions, verify that this action is on the list
		set exposedactions [lindex $::module::modinfo($module) 3]
		if {$exposedactions != "" && [lsearch -exact $exposedactions $action] == -1} {
			return ""
		}

		# Keep track of the current module stack
		namespace eval ::request::module {}
		lappend ::request::module::currentmodule $module

		# Call the module
		debug::log module::call "Calling module $module\(action=$action, subaction=$subaction)"
		set ret [${module}::${action} $subaction]

		# Pop the module call stack
		set ::request::module::currentmodule [lrange $::request::module::currentmodule 0 end-1]

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
	#	module flags icon desc exposedactions
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
			set exposedactions [lindex $::module::modinfo($module) 3]
			lappend ret [list $module $flags $icon $desc $exposedactions]
		}

		return $ret
	}

	# Name: ::module::current
	# Args: (none)
	# Rets: The name of the current module being called, or an
	#       empty string if called from the global scope
	# Stat: In progress
	proc current {} {
		if {[info exists ::request::module::currentmodule]} {
			set retval $::request::module::currentmodule
		} else {
			set retval ""
		}

		return $retval
	}
}
