package provide db 0.1

namespace eval db {

##########################################################################
# Proc: getuuid
# Args: 
#       *prefix            Optional prefix
# Rets: A Universally Unique ID on success, 0 on failure
# Meth: Random!
# Othr: (null)
# Stat: Complete
##########################################################################
proc getuuid {{prefix 0}} {
  ::set uuid [format "%x-%x-%x-%x" $prefix [clock clicks] [clock seconds] [clock clicks] [pid]]
  return $uuid
}

	if {[info exists mysqldb(user)] && [info exists mysqldb(pass)] && [info exists mysqldb(dbname)] && [info exists mysqldb(server)]} {
		catch {
			package require mysqltcl

##########################################################################
# Proc: set 
# Args:
#       dbname       Name of database to update
#       key          Key to associate with data.
#       data         Data
#       *expires     Unixtime of expiration
# Rets: 1 on success, 0 on failure.
# Meth: Write a value to a MySQL DB
# Note: (none)
# Stat: Complete
##########################################################################
proc set {dbname key data {expires -1}} {
	global mysqldb

	catch {
		::set dbhandle [connect $mysqldb(user) $mysqldb(pass) $mysqldb(dbname) $mysqldb(server)]
	}
	if {![info exists dbhandle]} { return 0 }

	mysqlexec $dbhandle "CREATE TABLE IF NOT EXISTS $dbname (dbkey VARCHAR(255) BINARY PRIMARY KEY, dbvalue LONGBLOB, dbexpires INT);"

	if {$expires!=-1} {
		mysqlexec $dbhandle "UPDATE $dbname SET dbexpires=$expires WHERE dbkey=[sqlquote $key];"
	}
	::set ret [mysqlexec $dbhandle "UPDATE $dbname SET dbvalue=[sqlquote $data] WHERE dbkey=[sqlquote $key];"]
	if {!$ret} {
		if {$expires==-1} {
			::set expires 0
		}

		if {[catch {
			::set ret [mysqlexec $dbhandle "INSERT INTO $dbname (dbkey, dbvalue, dbexpires) VALUES ([sqlquote $key], [sqlquote $data], $expires);"]
		}]} {
			::set ret [mysqlexec $dbhandle "DELETE FROM $dbname WHERE dbkey=[sqlquote $key];"]
			::set ret [mysqlexec $dbhandle "INSERT INTO $dbname (dbkey, dbvalue, dbexpires) VALUES ([sqlquote $key], [sqlquote $data], $expires);"]
		}
	}

	if {!$ret} {
		return 0
	}

	return 1
}

##########################################################################
# Proc: unset
# Args:
#       dbname       Name of database to update
#       key          Key to associate with data.
# Rets: 1 on success, 0 on failure.
# Meth: DELETE from a MySQL db
# Othr: 
# Stat: Complete
##########################################################################
proc unset {dbname key} {
	global mysqldb

	catch {
		::set dbhandle [connect $mysqldb(user) $mysqldb(pass) $mysqldb(dbname) $mysqldb(server)]
	}
	if {![info exists dbhandle]} { return 0 }

	::set ret [mysqlexec $dbhandle "DELETE FROM $dbname WHERE dbkey=[sqlquote $key]"];

	if {!$ret} {
		return 0
	}

	return 1
}

##########################################################################
# Proc: get
# Args:
#       dbname       Name of database to consult
#       key          Key associated with data.
#       *nocache     Ignore cache?
# Rets: Data associated with key, error if the key doesn't exist 
# Meth: Load a key from a MySQL database
# Othr: (none)
# Stat: Complete
##########################################################################
proc get {dbname key {nocache 0}} {
	global mysqldb

	::set dbhandle [connect $mysqldb(user) $mysqldb(pass) $mysqldb(dbname) $mysqldb(server)]

	::set ret [mysqlsel $dbhandle "SELECT dbvalue,dbexpires FROM $dbname WHERE dbkey=[sqlquote $key];" -flatlist]

	::set expires [lindex $ret 1]
	if {[clock seconds]>$expires && $expires!=0} {
		# Do cleanup
		::unset $dbname $key
		return -code error "No such key: ${dbname}->${key}"
	}

	return [lindex $ret 0]
}

##########################################################################
# Proc: listkeys
# Args:
#       dbname       Name of database to consult
#       *nocache     Ignore cache?
# Rets: List of keys in `dbname'
# Meth: Load keys from a MySQL database
# Othr: (none)
# Stat: Complete
##########################################################################
proc listkeys {dbname {nocache 0}} {
	global mysqldb

	catch {
		::set dbhandle [connect $mysqldb(user) $mysqldb(pass) $mysqldb(dbname) $mysqldb(server)]
	}
	if {![info exists dbhandle]} { return "" }

	::set ret [mysqlsel $dbhandle "SELECT dbkey,dbexpires FROM $dbname;" -flatlist]

	::set currtime [clock seconds]

	::set retval ""
	foreach {key expires} $ret {
		if {$currtime>$expires && $expires!=0} { continue }
		lappend retval $key
	}

	return $retval
}

##########################################################################
# Proc: connect
# Args:
#       user
#	pass
#	dbname
#	server
#       *nocache     Ignore cache?
# Rets: List of keys in `dbname'
# Meth: Load keys from a "TCL DB"
# Othr: Cached copy of database is stored in CACHEDB_${dbname}
# Stat: Complete
##########################################################################
proc connect {user pass dbname server} {
	global CACHEDBHandle
	if {[info exists CACHEDBHandle]} { return $CACHEDBHandle }

	catch {
		::set CACHEDBHandle [mysqlconnect -host $server -user $user -password $pass -db $dbname]
	}

	catch {
		after idle {
			catch {
				global CACHEDBHandle
				if {[info exists CACHEDBHandle]} {
					mysqlclose $CACHEDBHandle
					::unset CACHEDBHandle
				}
			}
		}
	}
 
	if {![info exists CACHEDBHandle]} { return -code error "Couldn't connect to database server." }
	return $CACHEDBHandle
}

##########################################################################
# Proc: sqlquote
# Args: 
# 	str	String to be quoted
# Rets: An SQL-safe-for-assignment string.
# Meth: map it.
# Othr: (null)
# Stat: Complete
##########################################################################
proc sqlquote {str} {
	global CACHEDBHandle
	if {[info exists CACHEDBHandle]} {
		::set ret "'[mysqlescape $CACHEDBHandle $str]'"
	} else {
		::set ret "'[mysqlescape $str]'"
	}

	return $ret
}


		}
	}


	if {[info procs get] == ""} {
		if {![info exists dbfilepat]} {
			::set dbfilepat {/var/tmp/$dbname.tcldb}
		}


##########################################################################
# Proc: set
# Args:
#       dbname       Name of database to update
#       key          Key to associate with data.
#       data         Data
#       *expires     Unixtime of expiration
# Rets: 1 on success, 0 on failure.
# Meth: Write a value to a "TCL DB"
# Othr: Cached copy of database is stored in CACHEDB_${dbname}
#       Must write to cache as CACHEDB_${dbname}
# Stat: Complete
##########################################################################
proc set {dbname key data {expires -1}} {
  global CACHEDB_${dbname}

  if {![load $dbname]} { return 0 }

  if {[info exists CACHEDB_${dbname}($key)] && $expires==-1} {
    ::set expires [lindex [subst \$CACHEDB_${dbname}($key)] 0]
  }
  if {$expires==-1} { ::set expires 0 }
  ::set CACHEDB_${dbname}($key) [list $expires $data]
  modifycallback CACHEDB_${dbname} $key write

  if {![save $dbname]} { return 0 }
  return 1
}

##########################################################################
# Proc: unset
# Args:
#       dbname       Name of database to update
#       key          Key to associate with data.
# Rets: 1 on success, 0 on failure.
# Meth: Write a value to a "TCL DB"
# Othr: Cached copy of database is stored in CACHEDB_${dbname}
#       Must unset to cache as CACHEDB_${dbname}
# Stat: Complete
##########################################################################
proc unset {dbname key} {
  global CACHEDB_${dbname}

  if {![load $dbname]} { return 0 }
#  ::set CACHEDB_${dbname}($key) "You have been erased."
  ::unset CACHEDB_${dbname}($key)
  modifycallback CACHEDB_${dbname} $key unset
  if {![save $dbname]} { return 0 }
  return 1
}

##########################################################################
# Proc: get
# Args:
#       dbname       Name of database to consult
#       key          Key associated with data.
#       *nocache     Ignore cache?
# Rets: Data associated with key, error if the key doesn't exist 
# Meth: Load a key from a "TCL DB"
# Othr: Cached copy of database is stored in CACHEDB_${dbname}
# Stat: Complete
##########################################################################
proc get {dbname key {nocache 0}} {
  upvar #0 CACHEDB_${dbname} dbdata
 
  if {![load $dbname $nocache]} { return -code error "Couldn't load database: $dbname" }
  if {![info exists dbdata($key)]} { return -code error "No such key: ${dbname}->${key}" }
  ::set expires [lindex $dbdata($key) 0]
  if {$expires!=0} {
    if {[clock seconds]>$expires} {
      ::unset dbdata($key)
      return -code error "No such key: ${dbname}->${key}"
    }
  }
  return [lindex $dbdata($key) 1]
}

##########################################################################
# Proc: listkeys
# Args:
#       dbname       Name of database to consult
#       *nocache     Ignore cache?
# Rets: List of keys in `dbname'
# Meth: Load keys from a "TCL DB"
# Othr: Cached copy of database is stored in CACHEDB_${dbname}
# Stat: Complete
##########################################################################
proc listkeys {dbname {nocache 0}} {
  upvar #0 CACHEDB_${dbname} dbdata
 
  if {![load $dbname $nocache]} { return -code error "Couldn't load database: $dbname" }
  if {![array exists dbdata]} { return "" }
  return [array names dbdata]
}

##########################################################################
# Proc: load
# Args:
#       dbname       Name of database to consult
#       *nocache     Ignore cache?
# Rets: 1 on success, 0 on failure (i.e., no such database)
# Meth: Load a "TCL DB"
# Othr: Cached copy of database is stored in CACHEDB_${dbname}
# Stat: Complete
##########################################################################
proc load {dbname {nocache 0}} {
  upvar #0 CACHEDB_${dbname} dbdata

  # If we're already loaded, merge the data back in.
  if {[info exists dbdata]} {
    # Use cache, if we can. 
    if {!$nocache} { return 1 }

    if {[info exists ::db::dbmodified($dbname)]} {
      foreach key $::db::dbmodified($dbname) {
        if {[info exists dbdata($key)]} {
          ::set backup($key) $dbdata($key)
        } else {
          ::set backup_unset($key) 1
        }
      }
    }
#    trace remove variable dbdata write modifycallback
  }

  ::set dbname [string map {/ _} $dbname]
  ::set dbfile [subst -nocommands -nobackslashes $::db::dbfilepat]

  # If the file exists, load it, nothing otherwise (but we still succeed).
  if {[file exists $dbfile]} {
    # If we can't read the database, we fail.
    if {![file readable $dbfile]} { return 0 }

    catch { source $dbfile }
  }

  foreach key [array names backup] { ::set dbdata($key) $backup($key) }
  foreach key [array names backup_unset] { ::unset -nocomplain dbdata($key) } 

#  trace add variable dbdata write modifycallback

  return 1
}

##########################################################################
# Proc: save
# Args:
#       dbname       Name of database to consult
# Rets: 1 on success, 0 on failure
# Meth: Save database from memory to disk
# Othr: Cached copy of database is stored in CACHEDB_${dbname}
# Stat: Complete
##########################################################################
proc save {dbname} {
  upvar #0 CACHEDB_${dbname} dbdata

  if {![info exists dbdata]} { return 0 }

  ::set dbname [string map {/ _} $dbname]
  ::set dbfile [subst -nocommands -nobackslashes $::db::dbfilepat]
  ::set dbfilelk "$dbfile.lk"

  # We succeed if there are no changes to write.
  if {![info exists ::db::dbmodified($dbname)]} {
    return 1
  }

  # Lock the file before attempting to screw with it.
#  if {![lockfile $dbfilelk 10 20]} { return 0 }
  catch { ::set fileId [open $dbfile a 0600] }
  if {![info exists fileId]} {
#    unlockfile $dbfilelk
    return 0
  }
  foreach key $::db::dbmodified($dbname) {
    if {[info exists dbdata($key)]} {
      puts $fileId [list ::set dbdata($key) $dbdata($key)]
    } else {
      puts $fileId [list ::unset -nocomplain dbdata($key)]
    }
  }
  close $fileId
#  unlockfile $dbfilelk
  ::unset ::db::dbmodified($dbname)

  return 1
}

##########################################################################
# Proc: modifycallback
# Args:
#       variable
#       entry
#       operation
# Rets: Always returns 0
# Meth: Appened to the list dbmodified($dbname) whenever CACHEDB_dbname
#       is written to (used with `trace add variable')
# Othr: (null)
# Stat: Complete
##########################################################################
proc modifycallback {variable entry operation} {
  ::set dbname [join [lrange [split $variable _] 1 end] _]

  if {![info exists ::db::dbmodified($dbname)]} {
    ::set ::db::dbmodified($dbname) ""
  }
  if {[lsearch -exact $::db::dbmodified($dbname) $entry]==-1} {
    lappend ::db::dbmodified($dbname) $entry
  }
  return 0
}

##########################################################################
# Proc: compact
# Args:
#       dbname       Name of database to compact
# Rets: 1 on success, 0 on failure
# Meth: Read database into memory and then spit it back out to disk
# Othr: Cached copy of database is stored in CACHEDB_${dbname}
# Stat: Complete
##########################################################################
proc compact {dbname} {
  upvar #0 CACHEDB_${dbname} dbdata

  if {![load $dbname 1]} { return 0 }
  if {![info exists dbdata]} { return 0 }

  ::set dbfile "[subst -nocommands -nobackslashes $::db::dbfilepat]"
  ::set dbtmpfile "$dbfile.tmp"
  ::set dbbakfile "$dbfile.bak"
  ::set dbfilelk "$dbfile.lk"

  # Lock the file before attempting to screw with it.
#  if {![lockfile $dbfilelk 10 20]} { return 0 }
  catch { ::set fileId [open $dbtmpfile w 0600] }
  if {![info exists fileId]} {
#    unlockfile $dbfilelk
    return 0
  }
  ::set currtime [clock seconds]
  foreach key [array names dbdata] {
    ::set expires [lindex $dbdata($key) 0]
    if {$currtime>$expires && $expires!=0} { continue }
    puts $fileId [list ::set dbdata($key) $dbdata($key)]
  }
  close $fileId

  catch { file delete $dbbakfile }
  file rename $dbfile $dbbakfile
  file rename $dbtmpfile $dbfile
#  unlockfile $dbfilelk

  return 1
}

	}
}

return 0
