package require mysqltcl
package require hook

package provide db 0.1


namespace eval db {
	# Name: ::db::genuuid
	# Args: 
	#       *prefix            Optional prefix
	# Rets: A Universally Unique ID on success, 0 on failure
	# Stat: Complete.
	proc genuuid {{prefix 0}} {
		::set uuid [format "%x-%x-%x-%x" $prefix [clock clicks] [clock seconds] [clock clicks] [pid]]
		return $uuid
	}

	# Proc: ::db::sqlquote
	# Args: 
	#	str		String to be quoted
	# Rets: An SQL-safe-for-assignment string.
	# Stat: Complete
	proc sqlquote {str} {
		global CACHEDBHandle
		if {[info exists CACHEDBHandle]} {
			::set ret "'[mysqlescape $CACHEDBHandle $str]'"
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
		global CACHEDBHandle

		# Disconnected already.
		if {![info exists CACHEDBHandle]} {
			return 1
		}

		catch {
			mysqlclose $CACHEDBHandle
		}
		::unset CACHEDBHandle

		return 1
	}

	# Name: ::db::connect
	# Args: (none)
	# Rets: Returns a handle that must be used to talk to the SQL database.
	# Stat: Complete.
	proc connect {} {
		global CACHEDBHandle
		if {[info exists CACHEDBHandle]} {
			return $CACHEDBHandle
		}

		catch {
			::set CACHEDBHandle [mysqlconnect -host $::config::db(server) -user $::config::db(user)  -password $::config::db(pass) -db $::config::db(dbname)]
		} connectError

		if {![info exists CACHEDBHandle]} {
			return -code error "error: Could not connect to SQL Server: $connectError"
		}

		after idle {
			disconnect
		}

		return $CACHEDBHandle
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

		::set dbhandle [connect]
		mysqlexec $dbhandle "CREATE TABLE IF NOT EXISTS $dbname ([join $fieldlist {, }]);"

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
			lappend fielddata [list $fieldname $fieldvalue]
			lappend fieldnames $fieldname
			lappend fieldvalues [sqlquote $fieldvalue]
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
			::set ret [mysqlexec $dbhandle "UPDATE $dbname SET [join $fieldassignlist {, }] WHERE $wherevar=[sqlquote $whereval];"]
		} else {
			if {[catch {
				::set ret [mysqlexec $dbhandle "INSERT INTO $dbname ([join $fieldnames {, }]) VALUES ([join $fieldvalues {, }]);"]
			} insertError]} {
				foreach line [mysqlsel $dbhandle "DESCRIBE $dbname;" -list] {
					::set field [lindex $line 0]
					::set keytype [string toupper [lindex $line 3]]
					if {$keytype == "PRI" || $keytype == "UNI" || $keytype == "KEY"} {
						::set fieldidx [lsearch -exact $fieldnames $field]
						if {$fieldidx != -1} {
							::set fieldvalue [lindex $fieldvalues $fieldidx]
							lappend where "$field=$fieldvalue"
						}
					}
				}
				foreach fieldpair $fielddata {
					::set fieldname [lindex $fieldpair 0]
					::set fieldvalue [lindex $fieldpair 1]
					lappend fieldassignlist "$fieldname=[sqlquote $fieldvalue]"
				}
				::set ret [mysqlexec $dbhandle "UPDATE $dbname SET [join $fieldassignlist {, }] WHERE [join $where { AND }];"]
	
			}
		}

		if {!$ret} {
			return 0
		}

		return 1
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

		::set dbhandle [connect]

		if {[info exists fields]} {
			::set ret 1
			foreach field $fields {
				::set rettmp [mysqlexec $dbhandle "UPDATE $dbname SET $field=NULL WHERE $wherevar=[sqlquote $whereval];"]
				if {!$rettmp} {
					::set ret 0
				}
			}
		} else {
			::set ret [mysqlexec $dbhandle "DELETE FROM $dbname WHERE $wherevar=[sqlquote $whereval];"]
		}

		if {!$ret} {
			return 0
		}

		return 1
	}

	# Name: ::db::get
	# Args: (dash method)
	#	-dbname name	Name of database to retrieve from.
	#	-fields list	List of fields to return  -OR-
	#	-field str	Field to return
	#	-all		Boolean conditional to return all or just one.
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
			::set fieldstr [join [lindex $args $fieldsidx] {, }]
			::set selmode "-list"
		}
		if {$fieldidx != 0} {
			::set fieldstr [lindex $args $fieldidx]
			::set selmode "-flatlist"
		}

		::set dbname [lindex $args $dbnameidx]

		::set dbhandle [connect]
		if {[info exists where]} {
			::set ret [mysqlsel $dbhandle "SELECT $fieldstr FROM $dbname WHERE $wherevar=[sqlquote $whereval];" $selmode]
		} else {
			::set ret [mysqlsel $dbhandle "SELECT $fieldstr FROM $dbname;" $selmode]
		}

		if {$allbool} {
			return $ret
		}

		return [lindex $ret 0]
	}

}
