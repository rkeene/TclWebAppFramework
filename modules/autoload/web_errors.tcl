if {![info exists sl_weberrors_loaded]} {
	set sl_weberrors_loaded 1

	catch {
		rename error real_error
	}

	proc error args {
		puts "</a>[string repeat "</td></tr></table>" 20]"
		puts "Error: $args<br>"
		abort_page
	}

}
