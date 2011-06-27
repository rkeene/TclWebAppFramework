package provide db 0.4.0

package require sqlite3
package require hook
package require debug
package require wa_uuid

namespace eval ::db {
	# Name: ::db::_tryeval
	# Args:
	#       args...      Passed to SQLite3's eval command
	# Rets: Return value from evaluation
	# Stat: In progress
	proc _tryeval {args} {
		::set dbhandle [connect]

		for {::set retry 0} {$retry < 30} {incr retry} {
			if {[catch {
				::set cmd [linsert $args 0 $dbhandle eval]
				::set retval [uplevel 1 $cmd]
			} err]} {
				disconnect

				::set dbhandle [connect]

				after [expr {($retry / 10) * 1000}]

				continue
			}

			return $retval
		}

		return -code error $err
	}

	# Name: ::db::disconnect
	# Args: (none)
	# Rets: 1 on success, 0 otherwise.
	# Stat: In progress
	proc disconnect {} {
		::unset -nocomplain ::db::cachefields

		# Disconnected already.
		if {![info exists ::db::CACHEDBHandle]} {
			return 1
		}

		hook::call db::disconnect::enter

		catch {
			$::db::CACHEDBHandle close
		}
		::unset ::db::CACHEDBHandle

		debug::log db "Disconnecting from SQLite3 database."

		hook::call db::disconnect::return 1

		return 1
	}

	# Name: ::db::connect
	# Args: (none)
	# Rets: Returns a handle that must be used to talk to the SQL database.
	# Stat: In progress
	proc connect {} {
		if {[info exists ::db::CACHEDBHandle]} {
			return $::db::CACHEDBHandle
		}

		hook::call db::connect::enter

		debug::log db "Connecting to the SQLite3 database."

		::unset -nocomplain ::db::cachefields

		catch {
			sqlite3 db::sqlite3_iface $::config::db(filename)

			::set ::db::CACHEDBHandle "db::sqlite3_iface"
		} connectError

		if {![info exists ::db::CACHEDBHandle]} {
			return -code error "error: Could not connect to SQL Server: $connectError"
		}

		hook::call db::connect::return $::db::CACHEDBHandle

		return $::db::CACHEDBHandle
	}

	# Name: ::db::create
	# Args: (dash method)
	#	-dbname name	Name of database to create.
	#	-fields list	List of columns in the database.
	# Rets: 1 on success (the database now exists with those fields)
	# Stat: In progress
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
					::set type($fieldname) "TEXT PRIMARY KEY"
					::set havekey 1
				}
				"k" {
					::set type($fieldname) "TEXT UNIQUE"
					::set havekey 1
				}
				"u" {
					::set type($fieldname) "BLOB UNIQUE"
				}
				default {
					::set type($fieldname) "BLOB"
				}
			}

			lappend newfields $fieldname
		}

		if {![info exists havekey]} {
			::set type([lindex $newfields 0]) "TEXT PRIMARY KEY"
		}

		foreach field $newfields {
			lappend fieldlist "$field $type($field)"
		}

		hook::call db::create::enter $dbname $newfields

		::set sqlstr "CREATE TABLE IF NOT EXISTS main.$dbname ([join $fieldlist {, }]);"

		debug::log db $sqlstr

		_tryeval $sqlstr

		hook::call db::create::return 1 $dbname $newfields

		return 1
	}

	# Name: ::db::set
	# Args: (dash method)
	#	-dbname	name	Name of database to modify
	#	-field name value Field to modify
	#	?-where	cond?	Conditions to decide where to modify
	# Rets: 1 on success, 0 otherwise.
	# Stat: In progress
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
			::set fieldvaluesarr($fieldname) $fieldvalue
			lappend fielddata [list $fieldname $fieldvalue]
			lappend fieldnames $fieldname
			lappend fieldvalues ":fieldvaluesarr($fieldname)"
		}

		if {[info exists where]} {
			hook::call db::set::enter $dbname $fielddata $where
		} else {
			hook::call db::set::enter $dbname $fielddata
		}

		::set ret 0

		if {[info exists where]} {
			::set wherework [split $where =]
			::set wherevar [lindex $wherework 0]
			::set whereval [join [lrange $wherework 1 end] =]
			::unset wherework

			foreach fieldname $fieldnames {
				lappend fieldassignlist "$fieldname = :fieldvaluesarr($fieldname)"
			}

			::set sqlstr "UPDATE main.$dbname SET [join $fieldassignlist {, }] WHERE $wherevar = :whereval;"
		} else {
			::set sqlstr "INSERT OR REPLACE INTO main.$dbname ([join $fieldnames {, }]) VALUES ([join $fieldvalues {, }]);"
		}

		debug::log db $sqlstr

		_tryeval $sqlstr

		::set ret 1

		if {$ret} {
			::set ret 1
		}

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
	# Stat: In progress
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

		if {[info exists fields]} {
			foreach field $fields {
				lappend fieldassignlist "$field = :NULL"
			}

			::set sqlstr "UPDATE main.$dbname SET [join $fieldassignlist {, }] WHERE $wherevar = :whereval;"
		} else {
			::set sqlstr "DELETE FROM main.$dbname WHERE $wherevar = :whereval"
		}

		debug::log db $sqlstr

		_tryeval $sqlstr

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
	# Stat: In progress
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

		::set fieldstr [join $fields {, }]

		::set dbname [lindex $args $dbnameidx]

		if {[info exists where]} {
			hook::call db::get::enter $dbname $fields $allbool $where
		} else {
			hook::call db::get::enter $dbname $fields $allbool
		}

		if {[info exists where]} {
			if {$allbool} {
				::set sqlstr "SELECT $fieldstr FROM main.$dbname WHERE $wherevar = :whereval;"
			} else {
				::set sqlstr "SELECT $fieldstr FROM main.$dbname WHERE $wherevar = :whereval LIMIT 1;"
			}
		} else {
			if {$allbool} {
				::set sqlstr "SELECT $fieldstr FROM $dbname;"
			} else {
				::set sqlstr "SELECT $fieldstr FROM $dbname LIMIT 1;"
			}

			::set selmode "-list"
		}

		debug::log db $sqlstr

		::set ret [list]

		_tryeval $sqlstr row {
			if {$selmode == "-list"} {
				::set tmplist_mode [list]
			}

			foreach field $fields {
				::set fieldval $row($field)
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
	# Stat: In progress
	proc fields args {
		::set dbnameidx [expr [lsearch -exact $args "-dbname"] + 1]
		::set typesidx [expr [lsearch -exact $args "-types"] + 1]
		::set types [expr {!!$typesidx}]

		if {$dbnameidx == 0} {
			return -code error "error: You must specify -dbname"
		}

		::set dbname [lindex $args $dbnameidx]

		if {[info exists ::db::cachefields([list $dbname $types])]} {
			return $::db::cachefields([list $dbname $types])
		}

		::set ret [list]

		::set sqlstr "SELECT sql FROM sqlite_master WHERE name = :dbname AND type = 'table';"

		debug::log db $sqlstr

		::set dbdesc [_tryeval $sqlstr]

		::set dbdesc [lindex $dbdesc 0]

		::set dbdesc [regsub {^.*\((.*)\)$} $dbdesc {\1}]

		::set dbdesc [split $dbdesc ","]

		foreach field $dbdesc {
			::set field [split [string trim $field]]

			::set fieldname [lindex $field 0]

			if {$types} {
				::set fieldtype [string toupper [join [lrange $field 1 end]]]
				switch -- $fieldtype {
					"TEXT PRIMARY KEY" {
						append fieldname ":pk"
					}
					"TEXT UNIQUE" {
						append fieldname ":k"
					}
					"BLOB UNIQUE" {
						append fieldname ":u"
					}
				}
			}

			lappend ret $fieldname
		}

		::set ::db::cachefields([list $dbname $types]) $ret

		return $ret
	}
}
