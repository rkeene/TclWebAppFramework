package require debug
package require hook

hook::register * ::perfcheck

proc ::perfcheck {cid id args} {
	debug::log perfcheck "$id: $args"
}


