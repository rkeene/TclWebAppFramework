if {![info exists ::request::env(PATH_INFO)]} {
	if {[info exists ::request::args(module)]} {
		set ::request::req_module $::request::args(module)
	}
} else {
	set ::request::req_module [lindex [file split $::request::env(PATH_INFO)] 1]
}

if {![info exists ::request::req_module]} {
	set ::request::req_module "main"
} else {
	set ::request::req_module [lindex [file split $::request::req_module] 0]
}

if {![info exists ::request::module]} {
	set ::request::module $::request::req_module
}
