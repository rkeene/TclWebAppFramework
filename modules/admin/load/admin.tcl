package require user

namespace eval admin {
	proc init {} {
		return 1
	}

	proc main args {
		return "main.rvt"
	}

	proc new args {
		if {$args == "cancel"} {
			unset -nocomplain ::request::args(action) ::request::args(numopts)
			return [main]
		}

		if {![info exists ::request::args(numopts)]} {
			set ::request::args(numopts) 2
		}

		if {$args == "incrcnt"} {
			incr ::request::args(numopts)
			return "new.rvt"
		}
		if {$args == "deccnt"} {
			incr ::request::args(numopts) -1
			return "new.rvt"
		}

		if {[info exists ::request::args(set_username)]} {
			set newuid [user::create -user $::request::args(set_username) -name $::request::args(set_fullname) -pass $::request::args(set_password)]
			# Assume the user already exists if the addition failed
			# attempt to modify the exisitng user.
			if {$newuid == 0} {
				set newuid [user::getuid $::request::args(set_username)]
				if {$newuid != 0} {
					set check [user::change -uid $newuid -name $::request::args(set_fullname) -pass $::request::args(set_password)]
					if {!$check} {
						set newuid 0
					}
				}
			}

			# If we were able to create the user, update it.
			if {$newuid != 0} {
				set flags ""
				set optidxs ""
				foreach var [array names ::request::args] {
					switch -glob -- $var {
						"set_flag_*" {
							set flag [string range $var 9 end]
							lappend flags $flag
						}
						"set_opt_*_name" {
							set idx [lindex [split $var _] 2]
							lappend optidxs $idx
							set opts($idx.var) $::request::args($var)
						}
						"set_opt_*_val" {
							set idx [lindex [split $var _] 2]
							set opts($idx.val) $::request::args($var)
						}
					}
				}

				# Update flags
				user::change -uid $newuid -flags $flags

				# Unset all existing options.
				user::change -uid $newuid -opts ""

				# Update options
				foreach idx $optidxs {
					if {![info exists opts($idx.var)] || ![info exists opts($idx.val)]} {
						continue
					}

					user::setopt $newuid $opts($idx.var) $opts($idx.val)
				}

				# Cleanup
				foreach var [array names ::request::args] {
					if {[string match "set_*" $var]} {
						unset ::request::args($var)
					}
				}
				unset -nocomplain ::request::args(numopts)

				# Return the main module page.
				return [main]
			}

			# Set an informative error message
			set ::request::adminerror "Could not add user."
		}

 		return "new.rvt"
	}

	proc delete args {
		set update 0
		if {$args == "cancel"} {
			unset -nocomplain ::request::args(action) ::request::args(numopts)
			return [main]
		}
		if {$args == "change"} {
			set update 1
		}
		if {[info exists ::request::args(do_delusers)] && !$update} {
			foreach uid $::request::args(do_delusers) {
				user::delete $uid
			}

			unset -nocomplain ::request::args(action) ::request::args(do_delusers)
			return [main]
		} else {
			return "delete.rvt"
		}
	}

	proc modify args {
		if {$args == "cancel"} {
			unset -nocomplain ::request::args(action) ::request::args(numopts) ::request::args(modusers)
			return [main]
		}
		if {$args == "change"} {
			set update 1
		} else {
			set update 0
		}
		if {![info exists ::request::args(numopts)]} {
			set ::request::args(numopts) 2
		}
		if {$args == "incrcnt"} {
			incr ::request::args(numopts)
			return "modify.rvt"
		}
		if {$args == "deccnt"} {
			incr ::request::args(numopts) -1
			return "modify.rvt"
		}

		if {[info exists ::request::args(modusers)] && $args == "modify"} {
			# Now to actually update the specified users.
			if {![info exists ::request::args(do_exclude)]} {
				set ::request::args(do_exclude) ""
			}
			foreach uid $::request::args(modusers) {
				if {[lsearch -exact $::request::args(do_exclude) $uid] != -1} {
					continue
				}

				if {[info exists ::request::args(set_update_username)] && [info exists ::request::args(set_username)]} {
					user::change -uid $uid -user $::request::args(set_username)
				}
				if {[info exists ::request::args(set_update_fullname)] && [info exists ::request::args(set_fullname)]} {
					user::change -uid $uid -name $::request::args(set_fullname)
				}
				if {[info exists ::request::args(set_update_password)] && [info exists ::request::args(set_password)]} {
					user::change -uid $uid -pass $::request::args(set_password)
				}
				if {[info exists ::request::args(set_update_opts)]} {
					foreach var [array names ::request::args] {
						switch -glob -- $var {
							"set_flag_*" {
								set flag [string range $var 9 end]
								lappend flags $flag
							}
							"set_opt_*_name" {
								set idx [lindex [split $var _] 2]
								lappend optidxs $idx
								set opts($idx.var) $::request::args($var)
							}
							"set_opt_*_val" {
								set idx [lindex [split $var _] 2]
								set opts($idx.val) $::request::args($var)
							}
						}
					}

					# Update options
					foreach idx $optidxs {
						if {![info exists opts($idx.var)] || ![info exists opts($idx.val)]} {
							continue
						}
						user::setopt $uid $opts($idx.var) $opts($idx.val)
					}
				}
				if {[info exists ::request::args(set_update_flags)]} {
					foreach var [array names ::request::args] {
						if {![string match "set_flag_*" $var]} {
							continue
						}
						set flag [string range $var 9 end]
						set act $::request::args($var)
						switch -- $act {
							"set" {
								user::setflag $uid $flag
							}
							"unset" {
								user::unsetflag $uid $flag
							}
						}
					}
				}
			}

			unset -nocomplain ::request::args(action) ::request::args(numopts) ::request::args(modusers) ::request::args(do_exclude)
			return [main]
		}

		if {[info exists ::request::args(modusers)] && !$update} {
			return "modify.rvt"
		}

		return "modify-sel.rvt"
	}
}

module::register admin [list admin] admin.png "User Administration"
