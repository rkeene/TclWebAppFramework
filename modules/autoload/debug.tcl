set DEBUG 1

proc debug args {
	global DEBUG

	if {[info exists DEBUG]} {
		foreach statement $args {
			puts "DEBUG: $statement<br>"
		}
	}
}
