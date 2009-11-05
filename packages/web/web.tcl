package provide web 0.3

namespace eval ::web {
	proc _set_root {} {
		if {[info exists ::web::root]} {
			return
		}

		if {[info exists ::env(SCRIPT_NAME)]} {
			set ::web::root $::env(SCRIPT_NAME)
			set ::web::root [file dirname $::web::root]

			return
		}

		if {![info exists ::web::root]} {
			set ::web::root ""
		}
	}

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
		::web::_set_root

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

		set root $::web::root
		if {[string index $root end]=="/"} {
			set root [string range $root 0 end-1]
		}
		return "$root/$dest"
	}

	proc image {name alt class {filenameonly 0}} {
		::web::_set_root

		foreach chkfile [list local/static/images/$class/$name local/static/images/$class/$name.png static/images/$class/$name static/images/$class/$name.png local/static/images/$class/unknown.png static/images/$class/unknown.png] {
			if {[file exists $chkfile]} {
				set imgfile $chkfile
				break
			}
		}

		if {$class != "icons"} {
			set class "image-${class}"
		}

		if {![info exists imgfile]} {
			if {$filenameonly} {
				return ""
			} else {
				return "<div class=\"$class\">$alt</div>"
			}
		}

		set root $::web::root
		if {[string index $root end]=="/"} {
			set root [string range $root 0 end-1]
		}
		set imgurl "$root/$imgfile"
		if {$filenameonly} {
			return $imgurl
		} else {
			return "<img src=\"$imgurl\" alt=\"$alt\" class=\"$class\">"
		}
	}

	proc icon {icon alt} {
		return [image $icon $alt icons]
	}

	proc getarg {argname {default ""}} {
		if {[info exists ::request::args($argname)]} {
			return $::request::args($argname)
		}
		return $default
	}

	namespace eval ::web::widget {
		proc entry {name {default ""} {type text}} {
			set currval [::web::getarg $name $default]

			puts -nonewline "<input type=\"$type\" name=\"$name\" value=\"$currval\">"
		}

		proc password {name {default ""}} {
			return [entry $name $default password]
		}

		proc dropdown {name entries multiple {default ""} {size 1}} {
			set currval [::web::getarg $name $default]

			if {$multiple} {
				puts "<select name=\"$name\" size=\"$size\" multiple>"
			} else {
				puts "<select name=\"$name\" size=\"$size\">"
			}

			foreach entry $entries {
				set entry_val [lindex $entry 0]
				set entry_desc [lindex $entry 1]

				if {$entry_val == $currval} {
					set selected " selected"
				} else {
					set selected ""
				}

				puts "  <option value=\"$entry_val\"${selected}>$entry_desc</option>"
			}

			puts "</select>"
		}

		proc listbox {name entries size multiple {default ""}} {
			return [dropdown $name $entries $multiple $default $size]
		}

		proc checkbox {name checkedvalue text {default ""}} {
			set currval [::web::getarg $name $default]

			if {$currval == $checkedvalue} {
				set checked " checked"
			} else {
				set checked ""
			}

			puts -nonewline "<input type=\"checkbox\" name=\"$name\" value=\"$checkedvalue\"${checked}> $text<br>"
		}
	}
}
