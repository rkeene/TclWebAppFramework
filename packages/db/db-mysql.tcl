package provide db 0.3.0

package require mysqltcl
package require hook
package require debug
package require wa_uuid

namespace eval db {
	# Proc: ::db::sqlquote
	# Args: 
	#	str		String to be quoted
	# Rets: An SQL-safe-for-assignment string.
	# Stat: Complete
	proc sqlquote {str} {
		if {[info exists ::db::CACHEDBHandle]} {
			::set ret "'[mysqlescape $::db::CACHEDBHandle $str]'"
		} else {
			::set ret "'[mysqlescape $str]'"
		}

		return $ret
	}

	# Name: ::db::disconnect
	# Args: (none)
	# Rets: 1 on success, 0 otherwise.
	# Stat: Complete.
	proc disconnect {} {
		# Disconnected already.
		if {![info exists ::db::CACHEDBHandle]} {
			return 1
		}

		hook::call db::disconnect::enter

		catch {
			mysqlclose $::db::CACHEDBHandle
		}
		::unset ::db::CACHEDBHandle

		debug::log db "Disconnecting from MySQL database."

		hook::call db::disconnect::return 1

		return 1
	}

	# Name: ::db::connect
	# Args: (none)
	# Rets: Returns a handle that must be used to talk to the SQL database.
	# Stat: Complete
	proc connect {} {
		if {[info exists ::db::CACHEDBHandle]} {
			switch -- [mysqlstate $::db::CACHEDBHandle] {
				"NOT_A_HANDLE" {
					::unset ::db::CACHEDBHandle
				}
				"UNCONNECTED" {
					::unset ::db::CACHEDBHandle
				}
			}

			if {[info exists ::db::CACHEDBHandle]} {
				return $::db::CACHEDBHandle
			}
		}

		hook::call db::connect::enter

		debug::log db "Connecting to MySQL database."

		catch {
			::set ::db::CACHEDBHandle [mysqlconnect -host $::config::db(server) -user $::config::db(user)  -password $::config::db(pass) -db $::config::db(dbname)]
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
	# Stat: Complete.
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
					::set type($fieldname) "VARCHAR(255) PRIMARY KEY"
					::set havekey 1
				}
				"k" {
					::set type($fieldname) "VARCHAR(255) KEY"
					::set havekey 1
				}
				default {
					::set type($fieldname) "LONGBLOB"
				}
			}

			lappend newfields $fieldname
		}
		if {![info exists havekey]} {
			::set type([lindex $newfields 0]) "VARCHAR(255) PRIMARY KEY"
		}
		foreach field $newfields {
			lappend fieldlist "$field $type($field)"
		}

		hook::call db::create::enter $dbname $newfields

		::set dbhandle [connect]
		debug::log db "CREATE TABLE IF NOT EXISTS $dbname ([join $fieldlist {, }]);"

		if {[catch {
			mysqlexec $dbhandle "CREATE TABLE IF NOT EXISTS $dbname ([join $fieldlist {, }]);"
		}]} {
			disconnect
			::set dbhandle [connect]
			mysqlexec $dbhandle "CREATE TABLE IF NOT EXISTS $dbname ([join $fieldlist {, }]);"
		}

		hook::call db::create::return 1 $dbname $newfields

		return 1
	}

	# Name: ::db::set
	# Args: (dash method)
	#	-dbname	name	Name of database to modify
	#	-field name value Field to modify
	#	?-where	cond?	Conditions to decide where to modify
	# Rets: 1 on success, 0 otherwise.
	# Stat: Complete
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
			lappend fieldvalues [sqlquote $fieldvalue]
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
			foreach fieldpair $fielddata {
				::set fieldname [lindex $fieldpair 0]
				::set fieldvalue [lindex $fieldpair 1]
				lappend fieldassignlist "$fieldname=[sqlquote $fieldvalue]"
			}
			debug::log db "UPDATE $dbname SET [join $fieldassignlist {, }] WHERE $wherevar=[sqlquote $whereval];"
			if {[catch {
				mysqlexec $dbhandle "UPDATE $dbname SET [join $fieldassignlist {, }] WHERE $wherevar=[sqlquote $whereval];"
			}]} {
				disconnect
				::set dbhandle [connect]
				mysqlexec $dbhandle "UPDATE $dbname SET [join $fieldassignlist {, }] WHERE $wherevar=[sqlquote $whereval];"
			}
			::set ret 1
		} else {
			if {[catch {
				debug::log db "INSERT INTO $dbname ([join $fieldnames {, }]) VALUES ([join $fieldvalues {, }]);"
				::set ret [mysqlexec $dbhandle "INSERT INTO $dbname ([join $fieldnames {, }]) VALUES ([join $fieldvalues {, }]);"]
			} insertError]} {
				if {![info exists ::db::keys($dbname)]} {
					debug::log db "DESCRIBE $dbname;"
					if {[catch {
						::set dbdesc [mysqlsel $dbhandle "DESCRIBE $dbname;" -list]
					}]} {
						disconnect
						::set dbhandle [connect]
						::set dbdesc [mysqlsel $dbhandle "DESCRIBE $dbname;" -list]
					}
					foreach line $dbdesc {
						::set field [lindex $line 0]
						::set keytype [string toupper [lindex $line 3]]
						if {$keytype == "PRI" || $keytype == "UNI" || $keytype == "KEY"} {
							lappend ::db::keys($dbname) $field
						}
					}
				}
				foreach field $::db::keys($dbname) {
					::set fieldidx [lsearch -exact $fieldnames $field]
					if {$fieldidx != -1} {
						::set fieldvalue [lindex $fieldvalues $fieldidx]
						lappend where "$field=$fieldvalue"
					}
				}
				foreach fieldpair $fielddata {
					::set fieldname [lindex $fieldpair 0]
					::set fieldvalue [lindex $fieldpair 1]
					lappend fieldassignlist "$fieldname=[sqlquote $fieldvalue]"
				}
				debug::log db "UPDATE $dbname SET [join $fieldassignlist {, }] WHERE [join $where { AND }];"
				if {[catch {
					mysqlexec $dbhandle "UPDATE $dbname SET [join $fieldassignlist {, }] WHERE [join $where { AND }];"
				}]} {
					disconnect
					::set dbhandle [connect]
					mysqlexec $dbhandle "UPDATE $dbname SET [join $fieldassignlist {, }] WHERE [join $where { AND }];"
				}
				::set ret 1
			}
		}

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
	# Stat: Complete.
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
	# Stat: Complete
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
			::set fieldstr [join $fields {, }]
			::set selmode "-list"
		}
		if {$fieldidx != 0} {
			::set fields [lindex $args $fieldidx]
			::set fieldstr $fields
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
			debug::log db "SELECT $fieldstr FROM $dbname WHERE $wherevar=[sqlquote $whereval];"
			if {[catch {
				::set ret [mysqlsel $dbhandle "SELECT $fieldstr FROM $dbname WHERE $wherevar=[sqlquote $whereval];" $selmode]
			}]} {
				disconnect
				::set dbhandle [connect]
				::set ret [mysqlsel $dbhandle "SELECT $fieldstr FROM $dbname WHERE $wherevar=[sqlquote $whereval];" $selmode]
			}
		} else {
			debug::log db "SELECT $fieldstr FROM $dbname;"
			if {[catch {
				::set ret [mysqlsel $dbhandle "SELECT $fieldstr FROM $dbname;" $selmode]
			}]} {
				disconnect
				::set dbhandle [connect]
				::set ret [mysqlsel $dbhandle "SELECT $fieldstr FROM $dbname;" $selmode]
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
	# Stat: Complete
	proc fields args {
		::set dbnameidx [expr [lsearch -exact $args "-dbname"] + 1]
		if {$dbnameidx == 0} {
			return -code error "error: You must specify -dbname"
		}

		::set dbname [lindex $args $dbnameidx]

		::set ret ""

		::set dbhandle [connect]

		debug::log db "DESCRIBE $dbname;"

		if {[catch {
			::set dbdesc [mysqlsel $dbhandle "DESCRIBE $dbname;" -list]
		}]} {
			disconnect
			::set dbhandle [connect]
			::set dbdesc [mysqlsel $dbhandle "DESCRIBE $dbname;" -list]
		}

		foreach line $dbdesc {
			::set field [lindex $line 0]
			::set keytype [string toupper [lindex $line 3]]
			if {$keytype == "PRI" || $keytype == "UNI" || $keytype == "KEY"} {
				if {[info exists ::db::keys($dbname)]} {
					if {[lsearch -exact $::db::keys($dbname) $field] != -1} {
						continue
					}
				}
				lappend ::db::keys($dbname) $field
			}
			lappend ret $field
		}

		return $ret
	}
}
