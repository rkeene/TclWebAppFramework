package provide db 0.1

package require mysqltcl

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

	# Proc: sqlquote
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
	#	-dbname		Name of database to create.
	#	-fields		List of columns in the database.
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
			lappend fieldlist "$field LONGBLOB"
		}

		::set dbhandle [connect]
		mysqlexec $dbhandle "CREATE TABLE IF NOT EXISTS $dbname ([join $fieldlist ,]);"

		return 1
	}

	# Name: ::db::set
	# Args: (dash method)
	#	-dbname		Name of database to modify
	#	-field		Field to modify
	#	-where		Conditions to decide where to modify
	#	?--?		End of options
	#	value		Value to set matching records to
	# Rets: 1 on success, 0 otherwise.
	# Stat: Complete.
	proc set args {
		::set dbnameidx [expr [lsearch -exact $args "-dbname"] + 1]
		::set fieldidx [expr [lsearch -exact $args "-field"] + 1]
		::set whereidx [expr [lsearch -exact $args "-where"] + 1]
		::set stopidx [expr [lsearch -exact $args "--"] + 1]

		if {$stopidx == 0} {
			::set stopidx [expr [lindex [lsort -integer [list $dbnameidx $fieldidx $whereidx]] end] + 1]
		}
		if {$dbnameidx > $stopidx || $dbnameidx == 0} {
			return -code error "error: You must specify a dbname with -dbname."
		}
		if {$fieldidx > $stopidx || $fieldidx == 0} {
			return -code error "error: You must specify a field with -field."
		}
		if {$whereidx > $stopidx} {
			::set whereidx 0
		}

		if {$whereidx != 0} {
			::set where [lindex $args $whereidx]
		}
		::set dbname [lindex $args $dbnameidx]
		::set field [lindex $args $fieldidx]
		::set value [lindex $args $stopidx]

		::set dbhandle [connect]

		if {[info exists where]} {
			::set wherework [split $where =]
			::set wherevar [lindex $wherework 0]
			::set whereval [join [lrange $wherework 1 end] =]
			::unset wherework
			::set ret [mysqlexec $dbhandle "UPDATE $dbname SET $field=[sqlquote $value] WHERE $wherevar=[sqlquote $whereval];"]
		} else {
			::set ret [mysqlexec $dbhandle "INSERT INTO $dbname ($field) VALUES ([sqlquote $value]);"]
		}

		if {!$ret} {
			return 0
		}

		return 1
	}

	# Name: ::db::unset
	# Args: (dash method)
	#	-dbname		Name of database to modify
	#	-where		Conditions to decide where to unset
	#	?-fields?	Field to unset
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
	#	-dbname		Name of database to retrieve from.
	#	-field		Field to return.
	#	-all		Boolean conditional to return all or just one.
	#	?-where?	Conditions to decide where to read.
	# Rets: The value of the variable
	# Stat: Complete.
	proc get args {
		::set dbnameidx [expr [lsearch -exact $args "-dbname"] + 1]
		::set fieldidx [expr [lsearch -exact $args "-field"] + 1]
		::set whereidx [expr [lsearch -exact $args "-where"] + 1]
		::set allbool [expr !!([lsearch -exact $args "-all"] + 1)]
		if {$dbnameidx == 0 || $fieldidx == 0} {
			return -code error "error: You must specify -dbname and -field."
		}

		if {$whereidx != 0} {
			::set where [lindex $args $whereidx]
			::set wherework [split $where =]
			::set wherevar [lindex $wherework 0]
			::set whereval [join [lrange $wherework 1 end] =]
			::unset wherework
		}

		::set dbname [lindex $args $dbnameidx]
		::set field [lindex $args $fieldidx]

		::set dbhandle [connect]
		if {[info exists where]} {
			::set ret [mysqlsel $dbhandle "SELECT $field FROM $dbname WHERE $wherevar=[sqlquote $whereval];" -flatlist]
		} else {
			::set ret [mysqlsel $dbhandle "SELECT $field FROM $dbname;" -flatlist]
		}

		if {$allbool} {
			return $ret
		}

		return [lindex $ret 0]
	}

}
