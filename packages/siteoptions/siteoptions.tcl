package require db
package provide siteoptions 1.0

namespace eval siteoptions {}

namespace eval siteoptions {
	array set ::siteoptions::option [::list]

	proc list {} {
	}

	proc get {module option} {
	}

	proc set {module option value} {
	}

	# Name: ::siteoptions::register
	# Args:
	#       module          Name of module registering option
	#       option          Name of option
	#       default         Default value
	#       verifycallback  Callback for verification of data (blank for no verification)
	#       type            Type of option:
	#                                boolean
	#                                option
	#                                multioption (Like option, but many values may be selected)
	#                                optionorstring (Like option, but an "Other..." option that lets the user type in a string)
	#                                username
	#                                password
	#                                ip
	#                                string
	#                                text
	#   IF type == "boolean": None
	#   IF type == "option": List of options
	# Rets: 1 on success, 0 otherwise
	# Stat: In progress
	# Note: VerifyCallback should return a tuple with:
	#         {true/false Message}
	proc register {module option default verifycallback args} {
		if {[llength $args] < 1} {
			return -code error "wrong # args: should be \"::siteoptions::register module option default verifycallback \"$type\" ?options?\""
		}

		::set type [lindex $args 0]

		::set ::siteoptions::option([::list $module $option]) [::list type $type default $default callback $verifycallback]

		switch -- $type {
			"boolean" - "username" - "password" - "ip" - "string" - "text" {
				# No additional arguments required
				if {[llength $args] != 1} {
					return -code error "wrong # args: should be \"::siteoptions::register module option default verifycallback \"$type\"\""
				}
			}
			"option" - "multioption" - "optionorstring" {
				if {[llength $args] != 2} {
					return -code error "wrong # args: should be \"::siteoptions::register module option default verifycallback \"$type\" options\""
				}

				::set values [lindex $args 1]

				lappend ::siteoptions::option([::list $module $option]) values $values
			}
		}

		return 1
	}
}
