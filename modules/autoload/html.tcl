proc html_begin {} {
	global sl_pageinfo sl_css

	puts {<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
  <head>}
	if {[info exists sl_pageinfo(title)]} {
		puts "    <title>[join $sl_pageinfo(title) ::]</title>"
	}

	if {[info exists sl_css]} {
		puts {    <style type="text/css">}
		foreach cssent [lsort -dictionary [array names sl_css]] {
			puts "      $cssent {$sl_css($cssent)}"
		}
		puts {    </style>}
	}

	puts {  </head>
  <body>}
}

proc html_end {} {
	puts {  </body>
</html>}
}

proc text {text {class ""}} {
	if {$class==""} {
		return "$text"
	} else {
		return "<span class=\"$class\">$text</span>"
	}
}

proc div {text {class ""}} {
	if {$class==""} {
		return "<div>$text</div>"
	} else {
		return "<div class=\"$class\">$text</div>"
	}
}

proc p {text {class ""}} {
	if {$class==""} {
		return "<p>$text</p>"
	} else {
		return "<p class=\"$class\">$text</p>"
	}
}

proc hr {{width 100%}} {
	return "<hr width=\"$width\">"
}

proc a {url text {class ""}} {
	if {$class==""} {
		return "<a href=\"$url\">$text</a>"
	} else {
		return "<a href=\"$url\" class=\"$class\">$text</a>"
	}
}

proc br {} {
	return "<br>"
}

proc convtoext {str} {
	set ret ""
	for {set i 0} {$i<[string length $str]} {incr i} {
		set char [string index $str $i]
		if {[string match {[A-Za-z0-9.-]} $char]} {
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

set begin(00) html_begin
set end(00) html_end
