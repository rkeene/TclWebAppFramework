package provide db 0.3

package require Mk4tcl
package require hook
package require debug
package require wa_uuid

namespace eval db {
	# Name: ::db::disconnect
	# Args: (none)
	# Rets: 1 on success, 0 otherwise.
	# Stat: In progress..
	proc disconnect {} {
		mk::file close db
	}

	# Name: ::db::connect
	# Args: (none)
	# Rets: Returns a handle that must be used to talk to the SQL database.
	# Stat: In progress.
	proc connect {} {
		catch {
			mk::file open db /tmp/data.mk4
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
				}
				"k" {
					::set type($fieldname) "S"
				}
				default {
					::set type($fieldname) "B"
				}
			}

			lappend newfields $fieldname
		}
		foreach field $newfields {
			lappend fieldlist "$field:$type($field)"
		}

		hook::call db::create::enter $dbname $newfields

		::set dbhandle [connect]
		debug::log db "mk::view layout db.${dbname} $fieldlist"
		mk::view layout db.${dbname} $fieldlist

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

			debug::log db "mk::select db.${dbname} -exact $wherevar $whereval"
			::set idx [lindex [mk::select db.${dbname} -exact $wherevar $whereval] 0]
		} else {
			debug::log db "mk::row append db.${dbname}"
			::set idx [mk::row append db.${dbname}]
		}
		foreach fieldpair $fielddata {
			::set fieldname [lindex $fieldpair 0]
			::set fieldvalue [lindex $fieldpair 1]
			debug::log db "mk::set ${idx} $fieldname $fieldvalue"
			mk::set ${idx} $fieldname $fieldvalue
		}
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

		if {[info exists fields]} {
			::set ret 1
			foreach field $fields {
				debug::log db "UPDATE $dbname SET $field=NULL WHERE $wherevar=[sqlquote $whereval];"
				if {[catch {
					::set rettmp [mysqlexec $dbhandle "UPDATE $dbname SET $field=NULL WHERE $wherevar=[sqlquote $whereval];"]
				}]} {
					disconnect
					::set dbhandle [connect]
					::set rettmp [mysqlexec $dbhandle "UPDATE $dbname SET $field=NULL WHERE $wherevar=[sqlquote $whereval];"]
				}
				if {!$rettmp} {
					::set ret 0
				}
			}
		} else {
			debug::log db "DELETE FROM $dbname WHERE $wherevar=[sqlquote $whereval];"
			if {[catch {
				::set ret [mysqlexec $dbhandle "DELETE FROM $dbname WHERE $wherevar=[sqlquote $whereval];"]
			}]} {
				disconnect
				::set dbhandle [connect]
				::set ret [mysqlexec $dbhandle "DELETE FROM $dbname WHERE $wherevar=[sqlquote $whereval];"]
			}
		}

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
			debug::log db "mk::select db.${dbname} -exact $wherevar $whereval"
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
				debug::log db "mk::get ${idx} $field"
				::set fieldval [mk::get ${idx} $field]
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
		::set ret [mk::view info db.${dbname}]

		return $ret
	}
}