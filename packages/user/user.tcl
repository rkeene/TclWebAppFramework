package require db
package require hook
package require crypt

package provide user 0.1

namespace eval user {
	# Name: ::user::getuid
	# Args:
	#	username	Username to convert to a UID
	# Rets: The UID of the specified username.
	#	0 is returned if no user exists.
	# Stat: Complete
	proc getuid {username} {
		hook::call user::getuid::enter $username

		set uid [db::get -dbname user -field uid -where user=$username]

		if {$uid == "" || $uid == 0} {
			return 0
		}

		hook::call user::getuid::return $uid $username

		return $uid
	}

	# Name: ::user::getnam
	# Args:
	#	uid		UID to conver to a username.
	# Rets: The username of the specified UID.
	#	An empty string is returned if the user does not exist.
	# Stat: Complete
	proc getnam {uid} {
		hook::call user::getnam::enter $uid

		set username [get -uid $uid -user]

		hook::call user::getnam::return $username $uid

		return $username
	}

	# Name: ::user::login
	# Args:
	#	uid		UID of user to login.
	# Rets: 1 if the login was successful, 0 otherwise
	# Stat: In progress.
	proc login {uid} {
		# ...
		if {![exists $uid]} {
			return 0
		}

		return 1
	}

	# Name: ::user::create
	# Args:
	#	-user name	Username to create
	#	?-name fullname? Fullname of user
	#	?-flags list?	Flags for user
	#	?-opts list?	Options for user
	#	?-pass str?	Password for user
	# Rets: The UID of the new user, 0 on failure.
	# Stat: Complete
	proc create args {
		set useridx [expr [lsearch -exact $args "-user"] + 1]
		set nameidx [expr [lsearch -exact $args "-name"] + 1]
		set flagsidx [expr [lsearch -exact $args "-flags"] + 1]
		set optsidx [expr [lsearch -exact $args "-opts"] + 1]
		set passidx [expr [lsearch -exact $args "-pass"] + 1]

		if {$useridx == 0} {
			return -code error "error: You must specify atleast -user."
		}
		if {$nameidx != 0} {
			set name [lindex $args $nameidx]
		} else {
			set name ""
		}
		if {$flagsidx != 0} {
			set flags [lindex $args $flagsidx]
		} else {
			set flags ""
		}
		if {$optsidx != 0} {
			set opts [lindex $args $optsidx]
		} else {
			set opts ""
		}
		if {$passidx != 0} {
			set pass [lindex $args $passidx]
		} else {
			set pass "*LK*"
		}

		set user [lindex $args $useridx]

		hook::call user::create::enter $user $name $flags $opts $pass

		# Verify that the user does not already exist
		set check [db::get -dbname user -field uid -where user=$user]
		if {$check != ""} {
			return 0
		}

		set uid [db::genuuid 11]

		# TEMPORARY
		db::create -dbname user -fields [list uid user name flags opts pass]

		set success [db::set -dbname user -field uid $uid -field user $user -field name $name -field flags $flags -field opts $opts -field pass $pass]

		if {!$success} {
			return 0
		}

		hook::call user::create::return $uid $user $name $flags $opts $pass

		return $uid
	}

	# Name: ::user::delete
	# Args:
	#	uid		UID of user to delete
	# Rets: 1 on success, 0 otherwise
	# Stat: Complete
	proc delete {uid} {
		hook::call user::delete::enter $uid

		set success [db::unset -dbname user -where uid=$uid]

		hook::call user::delete::return $success $uid

		return $success
	}

	# Name: ::user::change
	# Args:
	#	-uid uid	UID of user to update
	# 	?-user str?	Change username to `str'
	#	?-name str?	Change fullname to `str'
	#	?-flags list?	Change flags list to `list'
	#	?-opts list?	Change opts list to `list'
	#	?-pass str?	Change password to `str'
	# Rets: 1 on success, 0 otherwise
	# Stat: Complete
	proc change args {
		set uididx [expr [lsearch -exact $args "-uid"] + 1]
		set useridx [expr [lsearch -exact $args "-user"] + 1]
		set nameidx [expr [lsearch -exact $args "-name"] + 1]
		set flagsidx [expr [lsearch -exact $args "-flags"] + 1]
		set optsidx [expr [lsearch -exact $args "-opts"] + 1]
		set passidx [expr [lsearch -exact $args "-pass"] + 1]

		if {$uididx == 0} {
			return -code error "error: You must specify -uid."
		}

		set uid [lindex $args $uididx]

		hook::call user::create::enter $uid $args

		set ret 1

		if {$useridx != 0} {
			set user [lindex $args $useridx]
			set check [db::set -dbname user -field user $user -where uid=$uid]
			if {!$check} {
				set ret 0
			}
		}
		if {$nameidx != 0} {
			set name [lindex $args $nameidx]
			set check [db::set -dbname user -field name $name -where uid=$uid]
			if {!$check} {
				set ret 0
			}
		}
		if {$flagsidx != 0} {
			set flags [lindex $args $flagsidx]
			set check [db::set -dbname user -field flags $flags -where uid=$uid]
			if {!$check} {
				set ret 0
			}
		}
		if {$optsidx != 0} {
			set opts [lindex $args $optsidx]
			set check [db::set -dbname user -field opts $opts -where uid=$uid]
			if {!$check} {
				set ret 0
			}
		}
		if {$passidx != 0} {
			set pass [crypt [lindex $args $passidx]]
			set check [db::set -dbname user -field pass $pass -where uid=$uid]
			if {!$check} {
				set ret 0
			}
		}

		hook::call user::create::return $ret $uid $args

		return $ret
	}

	# Name: ::user::get
	# Args:
	# 	-uid {uid|ALL}	UID to get information on
	#	?-user?		Return the username (string)
	#	?-name?		Return the fullname (string)
	#	?-flags?	Return the flags (list)
	#	?-opts?		Return the opts (list)
	#	?-uids?		Return the uids (str)
	#	?-pass?		Return the password (str)
	#	?-field str?	Return a list containing the specified element
	#	?-fields list?	Return a list containing lists of the specified
	#			elements (forces return to be a list of lists)
	# Rets: A string or list, depending on what is asked.
	#	A string is returned if `uid' is not specified as "ALL"
	#	and only one item is requested.
	#	A list of strings is returned if more than one item is requested
	#	and the UID is not specified as "ALL"
	#	A list of lists is returned if more than one item is requested
	#	and the UID is specified as "ALL"
	#	A list of strings is returned if one item is requested and the
	#	UID is specified as "ALL"
	# Stat: Complete
	proc get args {
		set fieldsidx [expr [lsearch -exact $args "-fields"] + 1]
		set uididx [expr [lsearch -exact $args "-uid"] + 1]
		set flagsidx [lsearch -exact $args "-flags"]
		set useridx [lsearch -exact $args "-user"]
		set nameidx [lsearch -exact $args "-name"]
		set optsidx [lsearch -exact $args "-opts"]
		set uidsidx [lsearch -exact $args "-uids"]
		set passidx [lsearch -exact $args "-pass"]

		if {$uididx == 0} {
			return -code error "error: You must specify atleast -uid."
		}

		if {$fieldsidx != 0} {
			foreach field [lindex $args $fieldsidx] {
				switch -- [string tolower $field] {
					"flags" { lappend fields "flags" }
					"user" { lappend fields "user" }
					"name" { lappend fields "name" }
					"pass" { lappend fields "pass" }
					"opts" { lappend fields "opts" }
					"uid" { lappend fields "uid" }
				}
			}
		}
		if {$useridx != -1} {
			lappend fields "user"
		}
		if {$nameidx != -1} {
			lappend fields "name"
		}
		if {$optsidx != -1} {
			lappend fields "opts"
		}
		if {$flagsidx != -1} {
			lappend fields "flags"
		}
		if {$uidsidx != -1} {
			lappend fields "uid"
		}
		if {$passidx != -1} {
			lappend fields "pass"
		}
		foreach fieldidx [lsearch -all -exact $args "-field"] {
			set field [lindex $args [expr $fieldidx + 1]]
			switch -- [string tolower $field] {
				"flags" { lappend fields "flags" }
				"user" { lappend fields "user" }
				"name" { lappend fields "name" }
				"pass" { lappend fields "pass" }
				"opts" { lappend fields "opts" }
				"uid" { lappend fields "uid" }
			}
		}

		set uid [lindex $args $uididx]

		if {$uid == "ALL"} {
			set wherecmd "-all"
		} else {
			set wherecmd "-where"
		}

		if {[llength $fields] == 1 && $fieldsidx == 0} {
			set fieldscmd "-field"
		} else {
			set fieldscmd "-fields"
		}

		hook::call user::get::enter $uid $fields

		set ret [db::get -dbname user $wherecmd uid=$uid $fieldscmd $fields]

		hook::call user::get::return $ret $uid $fields

		return $ret
	}

	# Name: ::user::hasflag
	# Args:
	#	uid		UID to check
	#	chkflags	List of flags to check for
	# Rets: 1 on success, 0 otherwise
	# Stat: Complete
	proc hasflag {uid chkflags} {
		set flags [string tolower [get -uid $uid -flags]]

		hook::call user::hasflag::enter $uid $chkflags

		foreach flag [string tolower $chkflags] {
			set found [lsearch -exact $flags $flag]
			if {$found == -1} {
				hook::call user::hasflag::return 0 $uid $chkflags
				return 0
			}
		}

		hook::call user::hasflag::return 1 $uid $chkflags

		return 1
	}

	# Name: ::user::setflag
	# Args:
	#	uid		UID to modify
	#	newflags	List of flags to set.
	# Rets: 1 on success, 0 otherwise
	# Stat: In progress
	proc setflag {uid newflags} {
		hook::call user::setflag::enter $uid $newflags

		set flags [string tolower [get -uid $uid -flags]]

		set update 0
		foreach flag [string tolower $newflags] {
			set found [lsearch -exact $flags $flag]

			if {$found == -1} {
				lappend flags [string tolower $flag]
				set update 1
			}
		}

		set check 1
		set ret 1

		if {$update} {
			set check [change -uid $uid -flags $flags]
		}

		if {!$check} {
			set ret 0
		}

		hook::call user::setflag::return $ret $uid $newflags $flags

		return $ret
	}

	# Name: ::user::unsetflag
	# Args:
	#	uid		UID to modify.
	#	newflags	List of flags to remove.
	# Rets: 1 on success, 0 otherwise
	# Stat: Complete
	proc unsetflag {uid delflags} {
		hook::call user::unsetflag::enter $uid $delflags

		set flags [string tolower [get -uid $uid -flags]]

		set delflags [string tolower $delflags]

		set update 0
		foreach flag $flags {
			set found [lsearch -exact $delflags $flag]

			if {$found != -1} {
				set update 1
				continue
			}

			lappend newflags $flag
		}

		set check 1
		set ret 1

		if {$update} {
			set check [change -uid $uid -flags $newflags]
		}

		if {!$check} {
			set ret 0
		}

		hook::call user::unsetflag::return $uid $delflags $newflags

		return $ret
	}

	# Name: ::user::setopt
	# Args:
	# 	uid		UID to modify
	#	opt		Option to set
	#	value		Value to set option to.
	# Rets: 1 on success, 0 otherwise
	# Stat: In progress
	proc setopt {uid opt value} {
		set opts [get -uid $uid -opts]
		
	}

	# Name: ::user::getopt
	# Args:
	# 	uid		UID to examine
	#	opt		Option to read
	# Rets: String value of `opt', empty string if not found
	# Stat: In progress
	proc getopt {uid opt} {
	}

	# Name: ::user::exists
	# Args:
	# 	uid		UID to check
	# Rets: 1 if the user exists, 0 otherwise
	# Stat: Complete
	proc exists {uid} {
		hook::call user::exists::enter $uid

		set ret 1

		set chkuid [get -uid $uid -uids]

		if {$chkuid != $uid} {
			set ret 0
		}

		hook::call user::exists::return $ret $uid

		return $ret
	}
}
