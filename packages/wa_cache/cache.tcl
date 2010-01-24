#! /usr/bin/env tclsh

#package require session
#package require db

namespace eval ::wa_cache {
	# Name: ::wa_cache::set
	# Args:
	#       level           Level of cache to set (request, session, global)
	#       ttl             Length of time to keep cache (seconds)
	#       module          Module which key is related
	#       key             Key to set
	#       value           Value to set
	# Rets: Value set
	# Stat: In progress
	proc set {level ttl module key value} {
		::set expiration [expr [clock seconds] + $ttl]

		unset $module $key

		switch -- $level {
			"request" {
				namespace eval ::request::wa_cache {}
				::set ::request::wa_cache::cached([list $module $key]) [list $expiration $value]
			}
			"session" {
				# XXX: TODO
				return -code error "Not implemented"
			}
			"global" {
				# XXX: TODO
				return -code error "Not implemented"
			}
		}

		return $value
	}

	# Name: ::wa_cache::unset
	# Args:
	#       module          Module which key is related
	#       ?key?           Key to clear, default is all keys
	# Rets: If key specified: previous value of key
	#       Otherwise: Unspecified
	# Stat: In progress
	proc unset {module {key ""}} {
		::set currtime [clock seconds]

		if {$key == ""} {
			::set ents [array names ::request::wa_cache::cached [list $module *]]
		} else {
			::set ents [list [list $module $key]]
		}

		::set retval ""
		foreach ent $ents {
			if {[info exists ::request::wa_cache::cached($ent)]} {
				::set data $::request::wa_cache::cached($ent)
				::set expiration [lindex $data 0]
				::set value [lindex $data 1]

				if {$currtime < $expiration || $expiration == 0} {
					::set retval $value
				}

				::unset ::request::wa_cache::cached($ent)
			}
		}

		return $retval
	}

	# Name: ::wa_cache::get
	# Args:
	#       module          Module which key is related
	#       key             Key to retrieve
	# Rets: Value set
	# Stat: In progress
	proc get {module key} {
		::set currtime [clock seconds]

		::set ent [list $module $key]

		if {[info exists ::request::wa_cache::cached($ent)]} {
			::set data $::request::wa_cache::cached($ent)
			::set expiration [lindex $data 0]
			::set value [lindex $data 1]

			if {$currtime < $expiration || $expiration == 0} {
				::set retval $value
			} else {
				::unset ::request::wa_cache::cached($ent)
			}
		}

		if {![info exists retval]} {
			return -code error "Value not found in cache: module=$module key=$key"
		}

		return $retval
	}

	# Name: ::wa_cache::clear
	# Args:
	#       module          Module which key is related
	#       ?level?         Level of cache to clear (request, session, global, all)
	# Rets: 
	# Stat: In progress
	proc clear {module {level ""}} {
		unset $module
	}
}

package provide wa_cache 0.1
