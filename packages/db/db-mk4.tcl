package provide db 0.4.0

package require Mk4tcl
package require hook
package require debug
package require wa_uuid

namespace eval ::db {
	proc __commit {{giveup 0}} {
		if {[info exists ::db::lockingstr]} {
			::set currlockholder [mk::get db.__webapplockingsystem!0 lockholder]
			if {$currlockholder != $::db::lockingstr} {
				return 0
				debug::log db::__commit "Unable to commit changes (lost lock)"
			}
		}

		if {[catch {
			if {$giveup} {
				debug::log db [list mk::set db.__webapplockingsystem!0 lockholder ""]
				mk::set db.__webapplockingsystem!0 lockholder ""
			}

			debug::log db [list mk::file commit db]
			mk::file commit db
		} err]} {
			debug::log db "   ** failed **"
			debug::log db::__commit "Unable to commit changes ($err)"
			return 0
		}

		return 1
	}

	# Name: ::db::disconnect
	# Args: (none)
	# Rets: 1 on success, 0 otherwise.
	# Stat: In progress..
	proc disconnect {} {
		# Verify that the DB is open
		array set opendbs [mk::file open]
		if {[lsearch -exact [array names opendbs] db] == -1} {
			# If not, return without making any changes.
			return
		}

		__commit 1

		if {[catch {
			debug::log db "mk::file close db"
			mk::file close db
		} err]} {
			debug::log db "  ** failed **"
			debug::log db::disconnect "Error while closing DB: $err"
		}
	}

	# Name: ::db::connect
	# Args: (none)
	# Rets: Returns a handle that must be used to talk to the SQL database.
	# Stat: In progress.
	proc connect {} {
		array set opendbs [mk::file open]
		if {[lsearch -exact [array names opendbs] db] != -1} {
			return
		}

		if {[file exists $::config::db(filename)]} {
			::set ::db::lockingstr [wa_uuid::gen]

			# Try to open the DB with a read-write lock
			while 1 {
				debug::log db [list mk::file open db $::config::db(filename) -readonly]
				mk::file open db $::config::db(filename) -readonly

				::set currlockholder "FAIL"
				catch {
					::set currlockholder [mk::get db.__webapplockingsystem!0 lockholder]
				}

				debug::log db [list mk::file close db]
				mk::file close db

				if {$currlockholder == ""} {
					break
				}

				debug::log db::connect "Unable to lock database, already held by $currlockholder -- waiting."
				after [expr int(rand() * 10000)]

			}
		}

		debug::log db [list mk::file open db $::config::db(filename) -nocommit]
		mk::file open db $::config::db(filename) -nocommit

		catch {
			debug::log db [list mk::set db.__webapplockingsystem!0 lockholder $::db::lockingstr]
			mk::set db.__webapplockingsystem!0 lockholder $::db::lockingstr

			debug::log db [list mk::file commit db]
			mk::file commit db
		}

		after idle [list db::disconnect]
	}

	# Name: ::db::create
	# Args: (dash method)
	#	-dbname name	Name of database to create.
	#	-fields list	List of columns in the database.
	# Rets: 1 on success (the database now exists with those fields)
	# Stat: In progress..
	proc create args {
		::set dbnameidx [expr [lsearch -exact $args "-dbname"] + 1]
		::set fieldsidx [expr [lsearch -exact $args "-fields"] + 1]
		if {$dbnameidx == 0 || $fieldsidx == 0} {
			return -code error "error: You must specify -dbname and -fields."
		}

		::set dbname [lindex $args $dbnameidx]
		::set fields [lindex $args $fieldsidx]

		if {[llength $fields] == 0} {
			return -code error "error: You must specify atleast one field."
		}

		foreach field $fields {
			::set fieldwork [split $field :]
			::set fieldname [lindex $fieldwork 0]
			::set fieldinfo [lindex $fieldwork 1]
			switch -- $fieldinfo {
				"pk" {
					::set type($fieldname) "S"
					lappend uniquefields $fieldname
				}
				"k" {
					::set type($fieldname) "S"
					lappend uniquefields $fieldname
				}
				default {
					::set type($fieldname) "B"
				}
			}

			lappend newfields $fieldname
		}

		if {![info exists uniquefields]} {
			::set uniquefield [list [lindex $newfields 0]]
			::set uniquefields [list $uniquefield]
			::set type($uniquefield) S
		}

		foreach field $newfields {
			lappend fieldlist "$field:$type($field)"
		}

		hook::call db::create::enter $dbname $newfields

		::set dbhandle [connect]

		if {[mk::view info db.__webapplockingsystem] == ""} {
			debug::log db [list mk::view layout db.__webapplockingsystem [list lockholder:S]]
			mk::view layout db.__webapplockingsystem [list lockholder:S]
			mk::set db.__webapplockingsystem!0 lockholder ""
		}

		if {[mk::view info db.__unique_fields] == ""} {
			debug::log db [list mk::view layout db.__unique_fields [list database:S fields:S]]
			mk::view layout db.__unique_fields [list database:S fields:S]
		}

		::set chkidx [mk::select db.__unique_fields -exact database $dbname]
		if {$chkidx != ""} {
			::set chkidx [lindex $chkidx 0]

			::set cursor "db.__unique_fields!${chkidx}"
			debug::log db "Database already found, updating unique fields: $cursor"
		} else {
			debug::log db "mk::row append db.__unique_fields"
			::set cursor [mk::row append db.__unique_fields]
		}

		debug::log db [list mk::set $cursor database $dbname fields $uniquefields]
		mk::set $cursor database $dbname fields $uniquefields

		debug::log db [list mk::view layout db.${dbname} $fieldlist]
		mk::view layout db.${dbname} $fieldlist

		debug::log db "mk::file commit db"
		mk::file commit db

		hook::call db::create::return 1 $dbname $newfields

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
			hook::call db::set::enter $dbname $fielddata $where
		} else {
			hook::call db::set::enter $dbname $fielddata
		}

		::set dbhandle [connect]

		if {[info exists where]} {
			::set wherework [split $where =]
			::set wherevar [lindex $wherework 0]
			::set whereval [join [lrange $wherework 1 end] =]
			::unset wherework

			debug::log db [list mk::select db.${dbname} -exact $wherevar $whereval]
			::set idx [lindex [mk::select db.${dbname} -exact $wherevar $whereval] 0]

			if {$idx == ""} {
				debug::log db "mk::row append db.${dbname}"
				::set idx [mk::row append db.${dbname}]

				debug::log db "mk::cursor position idx  (idx = $idx)"
				::set idx [mk::cursor position idx]

				debug::log db [list mk::set db.${dbname}!${idx} $wherevar $whereval]
				mk::set db.${dbname}!${idx} $wherevar $whereval
			}
		} else {
			debug::log db "mk::select db.__unique_fields -exact database $dbname"
			::set uniquefieldsidx [mk::select db.__unique_fields -exact database $dbname]

			if {$uniquefieldsidx != ""} {
				debug::log db "uniquefieldsidx = $uniquefieldsidx"
				::set uniquefieldsidx [lindex $uniquefieldsidx 0]

				debug::log db "mk::get db.__unique_fields!$uniquefieldsidx fields"
				::set uniquefields [mk::get db.__unique_fields!$uniquefieldsidx fields]
				debug::log db "   ** $uniquefields **"
			} else {
				::set uniquefields [list]
				debug::log db "   ** (not found) **"
			}

			foreach chkuniquefield $uniquefields {
				if {[lsearch -exact $fieldnames $chkuniquefield] != -1} {
					lappend overlappingfields $chkuniquefield
				}
			}
			if {[info exists overlappingfields]} {
				debug::log db "   ** (overlap) $overlappingfields **"
				::set cmdstr [list mk::select db.${dbname}]
				foreach overlappingfield $overlappingfields {
					lappend cmdstr -exact $overlappingfield $fieldmapping($overlappingfield)
				}

				debug::log db $cmdstr
				::set idx [eval $cmdstr]
				if {$idx == ""} {
					::unset idx
				}
			}

			if {![info exists idx]} {
				::set idx ""
			}

			if {$idx == ""} {
				debug::log db "mk::row append db.${dbname}"
				::set idx [mk::row append db.${dbname}]

				debug::log db "mk::cursor position idx  (idx = $idx)"
				::set idx [mk::cursor position idx]
			}
		}
		foreach fieldpair $fielddata {
			::set fieldname [lindex $fieldpair 0]
			::set fieldvalue [lindex $fieldpair 1]
			debug::log db [list mk::set db.${dbname}!${idx} $fieldname $fieldvalue]
			mk::set db.${dbname}!${idx} $fieldname $fieldvalue
		}

		__commit

		::set ret 1

		if {[info exists where]} {
			hook::call db::set::return $ret $dbname $fielddata $where
		} else {
			hook::call db::set::return $ret $dbname $fielddata
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
			hook::call db::unset::enter $dbname $where $fields
		} else {
			hook::call db::unset::enter $dbname $where
		}

		::set dbhandle [connect]

		debug::log db [list mk::select db.${dbname} -exact $wherevar $whereval]
		::set idxes [mk::select db.${dbname} -exact $wherevar $whereval]

		foreach idx $idxes {
			if {[info exists fields]} {
				foreach field $fields {
					debug::log db [list mk::set db.${dbname}!${idx} $field ""]
					mk::set db.${dbname}!${idx} $field ""
				}
			} else {
				debug::log db "mk::row delete db.${dbname}!${idx}"
				mk::row delete db.${dbname}!${idx}
			}
		}

		__commit

		::set ret 1

		if {$ret} {
			::set ret 1
		}

		if {[info exists fields]} {
			hook::call db::unset::return $ret $dbname $where $fields
		} else {
			hook::call db::unset::return $ret $dbname $where
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
			hook::call db::get::enter $dbname $fields $allbool $where
		} else {
			hook::call db::get::enter $dbname $fields $allbool
		}

		::set dbhandle [connect]

		if {[info exists where]} {
			debug::log db [list mk::select db.${dbname} -exact $wherevar $whereval]
			::set idxes [mk::select db.${dbname} -exact $wherevar $whereval]
		} else {
			debug::log db "mk::select db.${dbname}"
			::set idxes [mk::select db.${dbname}]
		}

		if {!$allbool} {
			::set idxes [lindex $idxes 0]
		}

		if {![info exists where]} {
			::set selmode "-list"
		}

		debug::log db "   -> $idxes"

		::set ret [list]
		foreach idx $idxes {
			if {$selmode == "-list"} {
				::set tmplist_mode [list]
			}

			foreach field $fields {
				debug::log db [list mk::get db.${dbname}!${idx} $field]
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
			if {[info exists where]} {
				::set ret [lindex $ret 0]
			}
		}

		if {[info exists where]} {
			hook::call db::get::return $ret $dbname $fields $allbool $where
		} else {
			hook::call db::get::return $ret $dbname $fields $allbool
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

		::set ret ""

		::set dbhandle [connect]

		debug::log db "mk::view info db.${dbname}"
		::set fields [mk::view info db.${dbname}]
		foreach field $fields {
			if {$types} {
				lappend ret $field
			} else {
				::set work [lindex [split $field :] 0]
				lappend ret $work
			}
		}

		return $ret
	}
}
