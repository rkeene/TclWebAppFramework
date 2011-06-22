#! /usr/bin/env tclsh

if {[llength $argv] != "3"} {
	puts stderr "Usage: db2db <in> <out> <tables>"
	puts stderr ""  
	puts stderr "Each <in> and <out> are \"dbid\" in the format of:"
	puts stderr "   <mode>:<parameters>"
	puts stderr ""
	puts stderr "Parameters for mode = mk4, sqlite:"
	puts stderr "   <filename>"
	puts stderr ""
	puts stderr "Parameters for mode = mysql"
	puts stderr "   <host>:<user>:<pass>:<database>"
	puts stderr ""
	puts stderr "Example: db2db mk4:test.mk4 sqlite:test.sqlite \"user sessions file\""

	exit 1
}

lappend auto_path [file normalize [file join [file dirname [info script]] .. local/packages]]
lappend auto_path [file normalize [file join [file dirname [info script]] .. packages]]
lappend auto_path [file normalize [file join [file dirname [info script]] .. lib]]

lappend auto_path "/usr/lib/tcl8.5"

proc parsedbid {dbid} {
	set work [split $dbid :]

	set mode [lindex $work 0]
	set params [lrange $work 1 end]

	set ret "namespace eval ::config {}\n"
	append ret "set ::config::db(mode) $mode\n"

	switch -- $mode {
		"sqlite" - "mk4" {
			append ret "set ::config::db(filename) [join $params :]\n"
		}
		"mysql" {
			error "Not implemented"
		}
	}

	return $ret
}

# Parse arguments
## Identifiers
set indbid [lindex $argv 0]
set outdbid [lindex $argv 1]

## Convert identifiers into meaningful values
set indb_script [parsedbid $indbid]
set outdb_script [parsedbid $outdbid]

# Create interpreters where work will be done
set indb [interp create]
set outdb [interp create]

# Initialize interpreters
## With DB configuration
$indb eval $indb_script
$outdb eval $outdb_script

## With package configuration
foreach interp [list $indb $outdb] {
	$interp eval [list set auto_path $auto_path]

	$interp eval [list package require debug]
	$interp eval [list debug::logfile -]

	$interp eval [list package require db]
}

# Perform copy
## Get a list of all the tables to copy
### XXX: TODO: For now, require the user to provide them.
set tables [lindex $argv 2]

## Create output table from input table and perform copy
foreach table $tables {
	set fields_types [$indb eval [list db::fields -types -dbname $table]]
	if {$fields_types == ""} {
		continue
	}

	$outdb eval [list db::create -dbname $table -fields $fields_types]

	### Get a list of all the fields for this table
	set fields [$indb eval [list db::fields -dbname $table]]

	### Copy every row
	set data [$indb eval [list db::get -dbname $table -fields $fields]]

	foreach row $data {
		set fields_cmd [list]

		foreach field $fields value $row {
			lappend fields_cmd -field $field $value
		}

		set cmd [linsert $fields_cmd 0 db::set -dbname $table]

		$outdb eval $cmd
	}
}

# Cleanup
foreach interp [list $indb $outdb] {
	$interp eval [list db::disconnect]
}
