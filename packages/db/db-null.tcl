package provide db 0.4.0

package require webapp::hook
package require wa_debug

namespace eval ::db {
	# Name: ::db::disconnect
	# Args: (none)
	# Rets: 1 on success, 0 otherwise.
	# Stat: In progress..
	proc disconnect {} {
		return 1
	}

	# Name: ::db::connect
	# Args: (none)
	# Rets: Returns a handle
	# Stat: In progress.
	proc connect {} {
		return "<null>"
	}

	# Name: ::db::create
	# Args: (dash method)
	#	-dbname name	Name of database to create.
	#	-fields list	List of columns in the database.
	# Rets: 1 on success (the database now exists with those fields)
	# Stat: In progress..
	proc create args {
		return 1
	}

	# Name: ::db::set
	# Args: (dash method)
	#	-dbname	name	Name of database to modify
	#	-field name value Field to modify
	#	?-where	cond?	Conditions to decide where to modify
	# Rets: 1 on success, 0 otherwise.
	# Stat: In progress.
	proc set args {
		::set dbnameidx [expr [lsearch -exact $args "-dbname"] + 1]
		::set fieldidx [expr [lsearch -exact $args "-field"] + 1]
		::set whereidx [expr [lsearch -exact $args "-where"] + 1]

		if {$dbnameidx == 0} {
			return -code error "error: You must specify a dbname with -dbname."
		}
		if {$fieldidx == 0} {
			return -code error "error: You must specify atleast one field with -field."
		}
		if {$whereidx != 0} {
			::set where [lindex $args $whereidx]
		}
		::set dbname [lindex $args $dbnameidx]
		foreach fieldidx [lsearch -all -exact $args "-field"] {
			::set fieldname [lindex $args [expr $fieldidx + 1]]
			::set fieldvalue [lindex $args [expr $fieldidx + 2]]
			lappend fielddata [list $fieldname $fieldvalue]
			lappend fieldnames $fieldname
			lappend fieldvalues $fieldvalue
			::set fieldmapping($fieldname) $fieldvalue
		}

		if {[info exists where]} {
			webapp::hook::call db::set::enter $dbname $fielddata $where
		} else {
			webapp::hook::call db::set::enter $dbname $fielddata
		}

		::set dbhandle [connect]

		if {[info exists where]} {
			::set wherework [split $where =]
			::set wherevar [lindex $wherework 0]
			::set whereval [join [lrange $wherework 1 end] =]
			::unset wherework

			wa_debug::log db [list mk::select db.${dbname} -exact $wherevar $whereval]
			::set idx [lindex [mk::select db.${dbname} -exact $wherevar $whereval] 0]

			if {$idx == ""} {
				wa_debug::log db "mk::row append db.${dbname}"
				::set idx [mk::row append db.${dbname}]

				wa_debug::log db "mk::cursor position idx  (idx = $idx)"
				::set idx [mk::cursor position idx]

				wa_debug::log db [list mk::set db.${dbname}!${idx} $wherevar $whereval]
				mk::set db.${dbname}!${idx} $wherevar $whereval
			}
		} else {
			wa_debug::log db "mk::select db.__unique_fields -exact database $dbname"
			::set uniquefieldsidx [mk::select db.__unique_fields -exact database $dbname]

			if {$uniquefieldsidx != ""} {
				wa_debug::log db "uniquefieldsidx = $uniquefieldsidx"
				::set uniquefieldsidx [lindex $uniquefieldsidx 0]

				wa_debug::log db "mk::get db.__unique_fields!$uniquefieldsidx fields"
				::set uniquefields [mk::get db.__unique_fields!$uniquefieldsidx fields]
				wa_debug::log db "   ** $uniquefields **"
			} else {
				::set uniquefields [list]
				wa_debug::log db "   ** (not found) **"
			}

			foreach chkuniquefield $uniquefields {
				if {[lsearch -exact $fieldnames $chkuniquefield] != -1} {
					lappend overlappingfields $chkuniquefield
				}
			}
			if {[info exists overlappingfields]} {
				wa_debug::log db "   ** (overlap) $overlappingfields **"
				::set cmdstr [list mk::select db.${dbname}]
				foreach overlappingfield $overlappingfields {
					lappend cmdstr -exact $overlappingfield $fieldmapping($overlappingfield)
				}

				wa_debug::log db $cmdstr
				::set idx [eval $cmdstr]
				if {$idx == ""} {
					::unset idx
				}
			}

			if {![info exists idx]} {
				::set idx ""
			}

			if {$idx == ""} {
				wa_debug::log db "mk::row append db.${dbname}"
				::set idx [mk::row append db.${dbname}]

				wa_debug::log db "mk::cursor position idx  (idx = $idx)"
				::set idx [mk::cursor position idx]
			}
		}
		foreach fieldpair $fielddata {
			::set fieldname [lindex $fieldpair 0]
			::set fieldvalue [lindex $fieldpair 1]
			wa_debug::log db [list mk::set db.${dbname}!${idx} $fieldname $fieldvalue]
			mk::set db.${dbname}!${idx} $fieldname $fieldvalue
		}

		__commit

		::set ret 1

		if {[info exists where]} {
			webapp::hook::call db::set::return $ret $dbname $fielddata $where
		} else {
			webapp::hook::call db::set::return $ret $dbname $fielddata
		}

		return $ret
	}

	# Name: ::db::unset
	# Args: (dash method)
	#	-dbname name	Name of database to modify
	#	-where cond	Conditions to decide where to unset
	#	?-fields list?	Field to unset
	# Rets: 1 on success, 0 otherwise.
	# Stat: In progress..
	proc unset args {
		::set dbnameidx [expr [lsearch -exact $args "-dbname"] + 1]
		::set fieldsidx [expr [lsearch -exact $args "-fields"] + 1]
		::set whereidx [expr [lsearch -exact $args "-where"] + 1]
		if {$dbnameidx == 0 || $whereidx == 0} {
			return -code error "error: You must specify -dbname and -where."
		}
		if {$fieldsidx != 0} {
			::set fields [lindex $args $fieldsidx]
		}
		::set dbname [lindex $args $dbnameidx]
		::set where [lindex $args $whereidx]
		::set wherework [split $where =]
		::set wherevar [lindex $wherework 0]
		::set whereval [join [lrange $wherework 1 end] =]
		::unset wherework

		if {[info exists fields]} {
			webapp::hook::call db::unset::enter $dbname $where $fields
		} else {
			webapp::hook::call db::unset::enter $dbname $where
		}

		::set dbhandle [connect]

		wa_debug::log db [list mk::select db.${dbname} -exact $wherevar $whereval]
		::set idxes [mk::select db.${dbname} -exact $wherevar $whereval]

		foreach idx $idxes {
			if {[info exists fields]} {
				foreach field $fields {
					wa_debug::log db [list mk::set db.${dbname}!${idx} $field ""]
					mk::set db.${dbname}!${idx} $field ""
				}
			} else {
				wa_debug::log db "mk::row delete db.${dbname}!${idx}"
				mk::row delete db.${dbname}!${idx}
			}
		}

		__commit

		::set ret 1

		if {$ret} {
			::set ret 1
		}

		if {[info exists fields]} {
			webapp::hook::call db::unset::return $ret $dbname $where $fields
		} else {
			webapp::hook::call db::unset::return $ret $dbname $where
		}

		return $ret
	}

	# Name: ::db::get
	# Args: (dash method)
	#	-dbname name	Name of database to retrieve from.
	#	-fields list	List of fields to return  -OR-
	#	-field str	Field to return
	#	?-all?		Boolean conditional to return all or just one.
	#	?-where cond?	Conditions to decide where to read.
	# Rets: The value of the variable
	# Stat: In progress.
	proc get args {
		::set dbnameidx [expr [lsearch -exact $args "-dbname"] + 1]
		::set fieldsidx [expr [lsearch -exact $args "-fields"] + 1]
		::set fieldidx [expr [lsearch -exact $args "-field"] + 1]
		::set whereidx [expr [lsearch -exact $args "-where"] + 1]
		::set allbool [expr !!([lsearch -exact $args "-all"] + 1)]

		if {$fieldsidx == 0 && $fieldidx == 0} {
			return -code error "error: You may only specify one of -field or -fields."
		}
		if {$dbnameidx == 0 || ($fieldsidx == 0 && $fieldidx == 0)} {
			return -code error "error: You must specify -dbname and -fields/-field."
		}

		if {$whereidx != 0} {
			::set where [lindex $args $whereidx]
			::set wherework [split $where =]
			::set wherevar [lindex $wherework 0]
			::set whereval [join [lrange $wherework 1 end] =]
			::unset wherework
		}

		if {$fieldsidx != 0} {
			::set fields [lindex $args $fieldsidx]
			::set selmode "-list"
		}
		if {$fieldidx != 0} {
			::set fields [list [lindex $args $fieldidx]]
			::set selmode "-flatlist"
		}

		::set dbname [lindex $args $dbnameidx]

		if {[info exists where]} {
			webapp::hook::call db::get::enter $dbname $fields $allbool $where
		} else {
			webapp::hook::call db::get::enter $dbname $fields $allbool
		}

		::set dbhandle [connect]

		if {[info exists where]} {
			wa_debug::log db [list mk::select db.${dbname} -exact $wherevar $whereval]
			::set idxes [mk::select db.${dbname} -exact $wherevar $whereval]
		} else {
			wa_debug::log db "mk::select db.${dbname}"
			::set idxes [mk::select db.${dbname}]
		}

		if {!$allbool} {
			::set idxes [lindex $idxes 0]
		}

		if {![info exists where]} {
			::set selmode "-list"
		}

		wa_debug::log db "   -> $idxes"

		::set ret [list]
		foreach idx $idxes {
			if {$selmode == "-list"} {
				::set tmplist_mode [list]
			}

			foreach field $fields {
				wa_debug::log db [list mk::get db.${dbname}!${idx} $field]
				::set fieldval [mk::get db.${dbname}!${idx} $field]
				switch -- $selmode {
					"-list" {
						lappend tmplist_mode $fieldval
					}
					"-flatlist" {
						lappend ret $fieldval
					}
				}
			}

			if {$selmode == "-list"} {
				lappend ret $tmplist_mode
			}
		}

		if {!$allbool} {
			if {[info exists where] || ([llength $fields] == 1 && $fieldsidx == 0)} {
				::set ret [lindex $ret 0]
			}
		}

		if {[info exists where]} {
			webapp::hook::call db::get::return $ret $dbname $fields $allbool $where
		} else {
			webapp::hook::call db::get::return $ret $dbname $fields $allbool
		}

		return $ret
	}

	# Name: ::db::fields
	# Args: (dash method)
	#	-dbname db	Database to list fields from
	#       ?-types?        Include type information
	# Rets: A list of fields in `db'
	# Stat: In progress.
	proc fields args {
		::set dbnameidx [expr [lsearch -exact $args "-dbname"] + 1]
		::set typesidx [expr [lsearch -exact $args "-types"] + 1]
		::set types [expr {!!$typesidx}]

		if {$dbnameidx == 0} {
			return -code error "error: You must specify -dbname"
		}

		::set dbname [lindex $args $dbnameidx]

		::set ret [list]

		::set dbhandle [connect]

		if {$types} {
			::set chkidx [mk::select db.__fields -exact database $dbname]
			if {$chkidx != ""} {
				::set chkidx [lindex $chkidx 0]

				::set cursor "db.__fields!${chkidx}"

				::set fields [mk::get $cursor fields]

				::set ret $fields
			}
		} else {
			wa_debug::log db "mk::view info db.${dbname}"

			::set fields [mk::view info db.${dbname}]

			foreach field $fields {
				::set work [lindex [split $field :] 0]
				lappend ret $work
			}
		}

		return $ret
	}
}
