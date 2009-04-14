package provide db 0.3.0

package require Mk4tcl
package require hook
package require debug
package require wa_uuid

namespace eval db {
	# Name: ::db::disconnect
	# Args: 
	#         readonly        Describe whether DB was open read-only or not
	# Rets: 1 on success, 0 otherwise.
	# Stat: In progress..
	proc disconnect {{readonly 1}} {
		# Verify that the DB is open
		array set opendbs [mk::file open]
		if {[lsearch -exact [array names opendbs] db] == -1} {
			# If not, return without making any changes.
			return
		}

		catch {
			debug::log db "mk::file close db"
			mk::file close db
		}

		if {!$readonly} {
			::set lockfile $::config::db(filename).lock
			catch {
				debug::log db "Removing lockfile."
				file delete -force -- $lockfile
			}
		}
	}

	# Name: ::db::connect
	# Args: (none)
	# Rets: Returns a handle that must be used to talk to the SQL database.
	# Stat: In progress.
	proc connect {} {
		array set opendbs [mk::file open]
		if {[lsearch -exact [array names opendbs] db] == -1} {
			::set lockfile $::config::db(filename).lock
			for {::set i 0} {$i < 300} {incr i} {
				catch {
					::set fd [open $lockfile [list WRONLY CREAT EXCL]]
				}
				if {[info exists fd]} {
					close $fd
					break
				}
				after 100
			}

			if {[info exists fd]} {
				::set readonly 0
			} else {
				debug::log db "Unable to create lock file, opening read-only and hoping for the best."
				::set readonly 1
			}

			if {$readonly} {
				debug::log db [list mk::file open db $::config::db(filename) -nocommit -readonly]
				mk::file open db $::config::db(filename) -nocommit -readonly
			} else {
				debug::log db [list mk::file open db $::config::db(filename) -extend -nocommit]
				mk::file open db $::config::db(filename) -extend -nocommit
			}

			after idle [list db::disconnect $readonly]
		}
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

		if {[mk::view info db.__unique_fields] == ""} {
			debug::log db [list mk::view layout db.__unique_fields {database:S fields:S}]
			mk::view layout db.__unique_fields "database:S fields:S"
		}

		debug::log db "mk::row append db.__unique_fields"
		::set cursor [mk::row append db.__unique_fields]

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
			::set fieldmapping($fieldnames) $fieldvalues
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
		} else {
			debug::log db "mk::select db.__unique_fields -exact database $dbname"
			::set uniquefieldsidx [mk::select db.__unique_fields -exact database $dbname]

			if {$uniquefieldsidx != ""} {
				debug::log db      "mk::get db.__unique_fields!$uniquefieldsidx fields"
				::set uniquefields [mk::get db.__unique_fields!$uniquefieldsidx fields]
				debug::log db "   => $uniquefields"
			} else {
				::set uniquefields [list]
				debug::log db "   => (not found)"
			}

			foreach chkuniquefield $uniquefields {
				if {[lsearch -exact $fieldnames $chkuniquefield] != -1} {
					lappend overlappingfields $chkuniquefield
				}
			}
			if {[info exists overlappingfields]} {
				debug::log db "  =overlap=> $overlappingfields"
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
		debug::log db "mk::file commit db"
		mk::file commit db

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
		debug::log db "mk::file commit db"
		mk::file commit db

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
	#	-all		Boolean conditional to return all or just one.
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
			return -code error "error: You must specify -dbname and -fields."
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
			::set fields [lindex $args $fieldidx]
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
			::set idxes [mk::select db.${dbname}"]
		}

		::set ret [list]
		foreach idx $idxes {
			if {$selmode == "-list"} {
				set tmplist [list]
			}
			foreach field $fields {
				debug::log db [list mk::get db.${dbname}!${idx} $field]
				::set fieldval [mk::get db.${dbname}!${idx} $field]
				switch -- $selmode {
					"-list" {
						lappend tmplist $fieldval
					}
					"-flatlist" {
						lappend ret $fieldval
					}
				}
			}
			if {$selmode == "-list"} {
				lappend ret $tmplist
			}
		}

		if {!$allbool} {
			::set ret [lindex $ret 0]
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
	# Rets: A list of fields in `db'
	# Stat: In progress.
	proc fields args {
		::set dbnameidx [expr [lsearch -exact $args "-dbname"] + 1]
		if {$dbnameidx == 0} {
			return -code error "error: You must specify -dbname"
		}

		::set dbname [lindex $args $dbnameidx]

		::set ret ""

		::set dbhandle [connect]

		debug::log db "mk::view info db.${dbname}"
		::set fields [mk::view info db.${dbname}]
		foreach field $fields {
			set work [lindex [split $field :] 0]
			lappend ret $work
		}

		return $ret
	}
}
