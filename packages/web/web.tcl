package provide web 0.1

namespace eval web {
	proc convtoext {str} {
		set ret ""
		for {set i 0} {$i<[string length $str]} {incr i} {
			set char [string index $str $i]
			if {[regexp {^[A-Za-z0-9.-]$} $char]} {
				append ret $char
			} else {
				set ascii [scan $char "%c"]
				append ret %[format "%02x" $ascii]
			}
		}

		return $ret
	}

	proc generate_vars {{method FORM} {extras ""} {noargs 0}} {
		set ret ""

		switch -- [string tolower $method] {
			form { set joinchar "\n" }
			url { set joinchar "&" }
		}

		set varval ""
		if {$extras!=""} {
			foreach {var val} $extras {
				set used($var) 1
				lappend varval $var $val
			}
		}
		if {!$noargs} {
			foreach var [array names ::request::args] {
				if {$var == "submit" || [string match "set_*" $var] || [string match "do_*" $var] || [string match "subaction*" $var]} {
					continue
				}
				set val $::request::args($var)
				if {![info exists used($var)]} {
					lappend varval $var $val
				}
			}
		}

		foreach {var val} $varval {
			switch -- [string tolower $method] {
				form {
					lappend ret "<input type=\"hidden\" name=\"$var\" value=\"$val\">"
				}
				url {
					lappend ret "[convtoext $var]=[convtoext $val]"
				}
			}
		}

		return [join $ret $joinchar]
	}

	proc makeurl {dest {includevars 0} {vars ""}} {
		global root

		if {![info exists root]} {
			set root ""
		}
	
		if {[string match {*\?*} $dest]} {
			set joinchar "&"
		} else {
			set joinchar "?"
		}
		set appenddata [generate_vars url $vars [expr !$includevars]]
		if {$appenddata!=""} {
			append dest $joinchar $appenddata
		}

		if {[string index $dest 0]=="/"} { set dest [string range $dest 1 end] }
		if {[string index $root end]=="/"} { set root [string range $root 0 end-1] }
		return "$root/$dest"
	}

	proc icon {icon alt {class "icon"}} {
		global root

		if {![info exists root]} {
			set root ""
		}
	
		foreach chkfile [list local/static/images/icons/$icon local/static/images/icons/$icon.png static/images/icons/$icon static/images/icons/$icon.png] {
			if {[file exists $chkfile]} {
				set iconfile $chkfile
				break
			}
		}

		if {![info exists iconfile]} {
			set iconfile "static/images/icons/unknown.png"
		}

		return "<img src=\"$root/$iconfile\" alt=\"$alt\" class=\"$class\">"
	}
}
