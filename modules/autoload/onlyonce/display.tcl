proc display {page module} {
	if {$page == ""} {
		# XXX handle error
	} else {
		if {[string index $page 0] == "/"} {
			# Absolute path
			foreach parsepage [list local/$page ./$page] {
				if {[file exists $parsepage]} {
					debug::log display "Loading $parsepage"
					parse $parsepage
					break
				}
			}
		} else {
			# Relative path
			foreach parsepage [list local/modules/$module/$page modules/$module/$page] {
				if {[file exists $parsepage]} {
					debug::log display "Loading $parsepage"
					parse $parsepage
					break
				}
			}
		}
	}
}
