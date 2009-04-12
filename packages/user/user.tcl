package provide user 0.1

package require db
package require hook
package require crypt
package require wa_uuid
package require module
package require session

wa_uuid::register 11 user

namespace eval user {
	set badflag(limit) 1

	# Name: ::user::getuid
	# Args:
	#	?username?	Username to convert to a UID
	#			If not specified, current UID is returned.
	# Rets: The UID of the specified username.
	#	0 is returned if no user exists.
	# Stat: Complete
	proc getuid {{username ""}} {
		hook::call user::getuid::enter $username

		if {$username == ""} {
			if {[info exists ::session::vars(uid)]} {
				return $::session::vars(uid)
			}
			return 0
		}

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
	#	pass		Password to verify
	#	from		IP address of user
	# Rets: 1 if the login was successful, 0 otherwise
	# Stat: In progress.
	proc login {uid pass from} {
		if {![exists $uid]} {
			debug::log user::login "User doesn't exist ($uid)"
			return 0
		}

		set realpass [get -uid $uid -pass]
		set realsalt [string range $realpass 0 1]
		set chkpass [crypt $pass $realsalt]

		if {$chkpass != $realpass} {
			debug::log user::login "Failed password ($chkpass != $realpass)"
			return 0
		}

		set seturet [user::setuid $uid 1]
		if {$seturet == 0} {
			debug::log user::login "Could not setuid !"
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
		# Require admin to create a user.
		if {![hasflag "admin"]} {
			debug::log user::create "Attempting to create user without admin flag!"
			return 0
		}

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
			set passplain [lindex $args $passidx]
			if {$passplain == ""} {
				set pass "*LK*"
			} else {
				set pass [crypt $passplain]
			}
		} else {
			set pass "*LK*"
		}

		set user [lindex $args $useridx]

		if {$user == ""} {
			debug::log user::create "User specified as blank!"
			return 0
		}

		# Require the root flag to set the root flag.
		if {[lsearch -exact $flags "root"] != -1 && ![hasflag "root"]} {
			debug::log user::create "Non-root user tried to create root user!"
			return 0
		}

		# Verify that the user does not already exist
		set check [db::get -dbname user -field uid -where user=$user]
		if {$check != ""} {
			debug::log user::create "Tried to create user with existing username!"
			return 0
		}

		hook::call user::create::enter $user $name $flags $opts $pass

		set uid [wa_uuid::gen user]

		set success [db::set -dbname user -field uid $uid -field user $user -field name $name -field flags $flags -field opts $opts -field pass $pass]

		if {!$success} {
			debug::log user::create "Failed to update database while creating user."
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
		# Require admin to delete a user.
		if {![hasflag "admin"]} {
			return 0
		}

		# Do not allow non-root users to delete root users.
		if {![hasflag "root"] && [hasflag "root" $uid]} {
			return 0
		}

		# Invalidate cache
		unset -nocomplain ::user::cache_get

		hook::call user::delete::enter $uid

		set success [db::unset -dbname user -where uid=$uid]

		hook::call user::delete::return $success $uid

		return $success
	}

	# Name: ::user::change
	# Args:
	#	?-uid uid?	UID of user to update
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

		if {$uididx != 0} {
			set uid [lindex $args $uididx]
		} else {
			set uid [getuid]
		}

		# Require admin to set information for other users.
		if {![hasflag "admin"] && $uid != [getuid]} {
			return 0
		}

		# Only allow those with root to modify root.
		if {[hasflag "root" $uid] && ![hasflag "root"]} {
			return 0
		}

		# Invalidate cache
		unset -nocomplain ::user::cache_get

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

			# Require admin to set any flag, and
			# Require root to set the root flag.
			if {![hasflag "admin"] || ([lsearch -exact $flags "root"] != -1 && ![hasflag "root"])} {
				set ret 0
			} else {
				set check [db::set -dbname user -field flags $flags -where uid=$uid]
				if {!$check} {
					set ret 0
				}
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
			set passplain [lindex $args $passidx]
			if {$passplain == ""} {
				set pass "*LK*"
			} else {
				set pass [crypt $passplain]
			}
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
	# 	?-uid {uid|ALL}? UID to get information on
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
	# Stat: In progress
	proc get args {
		if {[info exists ::user::cache_get($args)]} {
			return $::user::cache_get($args)
		}

		for {set idx 0} {$idx < [llength $args]} {incr idx} {
			set curr [lindex $args $idx]
			switch -- $curr {
				"-uid" {
					incr idx
					set uid [lindex $args $idx]
				}
				"-fields" {
					incr idx
					set specfields [lindex $args $idx]
				}
				"-flags" { lappend fields "flags" }
				"-user" { lappend fields "user" }
				"-name" { lappend fields "name" }
				"-pass" { lappend fields "pass" }
				"-opts" { lappend fields "opts" }
				"-uids" { lappend fields "uid" }
			}
		}
		if {![info exists uid]} {
			set uid [getuid]
		}

		if {[info exists specfields]} {
			foreach field $specfields {
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

		if {$uid == "ALL"} {
			set wherecmd "-all"
		} else {
			set wherecmd "-where"
		}

		if {[llength $fields] == 1 && ![info exists specfields]} {
			set fieldscmd "-field"
		} else {
			set fieldscmd "-fields"
		}

		hook::call user::get::enter $uid $fields

		set ret [db::get -dbname user $wherecmd uid=$uid $fieldscmd $fields]
		set ::user::cache_get($args) $ret

		hook::call user::get::return $ret $uid $fields

		return $ret
	}

	# Name: ::user::hasflag
	# Args:
	#	chkflags	List of flags to check for
	#	?uid?		UID to check
	# Rets: 1 on success, 0 otherwise
	# Stat: Complete
	proc hasflag {chkflags {uid ""}} {
		if {$uid == ""} {
			set uid [getuid]
		}

		if {[wa_uuid::type $uid] == "user"} {
			set flags [string tolower [get -uid $uid -flags]]
		} else {
			set flags $uid
		}

		hook::call user::hasflag::enter $uid $chkflags

		set rootchk [lsearch -exact $flags root]

		foreach flag [string tolower $chkflags] {
			set found [lsearch -exact $flags $flag]
			if {$rootchk != -1 && ![info exists ::user::badflag($flag)]} {
				set found 0
			}
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
	#	newflags	List of flags to set.
	#	?uid?		UID to modify
	# Rets: 1 on success, 0 otherwise
	# Flag: ADMIN
	# Stat: Complete
	proc setflag {newflags {uid ""}} {
		if {$uid == ""} {
			set uid [getuid]
		}

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
	#	delflags	List of flags to remove.
	#	?uid?		UID to modify.
	# Rets: 1 on success, 0 otherwise
	# Stat: Complete
	proc unsetflag {delflags {uid ""}} {
		if {$uid == ""} {
			set uid [getuid]
		}

		hook::call user::unsetflag::enter $uid $delflags

		set flags [string tolower [get -uid $uid -flags]]

		set delflags [string tolower $delflags]

		set update 0

		set newflags ""

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
	#	opt		Option to set
	#	value		Value to set option to.
	# 	?uid?		UID to modify
	# Rets: 1 on success, 0 otherwise
	# Stat: In progress
	proc setopt {opt value {uid ""}} {
		if {$uid == ""} {
			set uid [getuid]
		}

		set opts [get -uid $uid -opts]

		set optidx [lsearch -glob $opts [list $opt *]]

		if {$optidx == -1} {
			if {$value != ""} {
				lappend opts [list $opt $value]
			}
		} else {
			if {$value != ""} {
				set opts [lreplace $opts $optidx $optidx [list $opt $value]]
			} else {
				set optidxlo [expr $optidx - 1]
				set optidxpo [expr $optidx + 1]
				set opts [join [list [lrange $opts 0 $optidxlo] [lrange $opts $optidxpo end]]]
			}
		}

		set ret [change -uid $uid -opts $opts]

		return $ret
	}

	# Name: ::user::listopt
	# Args:
	#	opt		Option to check for
	#	?value?		Value for option to equal
	#	?case?		Case sensitive comparison?
	# Rets: A list of UIDs who have `opt' (or `opt' set to `value')
	# Stat: In progress
	proc listopt {opt {value ""} {case 0}} {
		set ret ""
		if {!$case} {
			set value [string tolower $value]
		}
		foreach useropt [get -uid ALL -fields [list uid opts]] {
			set uid [lindex $useropt 0]
			set opts [lindex $useropt 1]
			set optidx [lsearch -glob $opts [list $opt *]]
			if {$optidx == -1} {
				continue
			}

			if {$value != ""} {
				set chkvalue [lindex [lindex $opts $optidx] 1]
				if {!$case} {
					set chkvalue [string tolower $chkvalue]
				}
				if {$value != $chkvalue} {
					continue
				}
			}

			lappend ret $uid
		}

		return $ret
	}

	# Name: ::user::getopt
	# Args:
	#	opt		Option to read
	# 	?uid?		UID to examine (default to current)
	# Rets: String value of `opt', empty string if not found
	# Stat: In progress
	proc getopt {opt {uid ""}} {
		if {$uid == ""} {
			set uid [getuid]
		}

		set opts [get -uid $uid -opts]

		set ret ""

		set optidx [lsearch -glob $opts [list $opt *]]

		if {$optidx != -1} {
			set ret [lindex [lindex $opts $optidx] 1]
		}

		return $ret
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

	# Name: ::user::listflag
	# Args:
	#	flag		Flag to check for
	# Rets: A list of UIDs for users who have the flag specified.
	# Stat: Complete
	proc listflag {flag} {
		hook::call user::listflag::enter $flag

		set isbad [info exists ::user::badflag($flag)]

		set ret ""
		foreach chk [get -uid ALL -fields [list uid flags]] {
			set uid [lindex $chk 0]
			set flags [lindex $chk 1]

			# Root belongs to everything, except those bad ones.
			if {[lsearch -exact $flags root] != -1 && !$isbad} {
				lappend ret $uid
				continue
			}

			if {[lsearch -exact $flags $flag] != -1} {
				lappend ret $uid
			}
		}

		hook::call user::listflag::enter $ret $flag

		return $ret
	}

	# Name: ::user::flaglist
	# Args: (none)
	# Rets: List of flags that are available from either modules or
	#	attached to a user.  `:u' will be appened to the flag
	#	if it's not associated with any module.
	# Stat: In progress
	proc flaglist {} {
		set flags "root"

		foreach modinfo [module::list -all] {
			set modflags [lindex $modinfo 1]
			foreach modflag $modflags {
				if {[lsearch -exact $flags $modflag] == -1} {
					lappend flags $modflag
				}
			}
		}

		foreach userflags [user::get -uid ALL -flags] {
			foreach userflag $userflags {
				if {[lsearch -exact $flags $userflag] == -1 && [lsearch -exact $flags "$userflag:u"] == -1} {
					lappend flags "$userflag:u"
				}
			}
		}

		return [lsort -dictionary $flags]
	}

	# Name: ::user::setuid
	# Args:
	#	newuid		UID to switch to.
	#	?override?	Override security checks.
	# Rets: 1 on success, 0 otherwise
	# Stat: In progress
	proc setuid {newuid {override 0}} {
		if {$newuid == 0} {
			return 0
		}

		if {[wa_uuid::type $newuid] != "user"} {
			return 0
		}

		if {[info exists ::session::vars(uid)] && !$override} {
			if {![hasflag root $::session::vars(uid)]} {
				return 0
			}
		}

		set ::session::vars(uid) $newuid

		return 1
	}
}
