namespace eval ::db {}

if {![info exists ::db::mode]} {
	if {[info exists ::config::db(mode)]} {
		set ::db::mode $::config::db(mode)
	}
}
if {![info exists ::db::mode]} {
	if {[info exists ::config::db(server)]} {
		set ::db::mode mysql
	}
	if {[info exists ::config::db(file)]} {
		set ::db::mode "mk4"
	}
}
if {![info exists ::db::mode]} {
	set ::db::mode mysql
}

source [file join [file dirname [info script]] db-$::db::mode.tcl]
