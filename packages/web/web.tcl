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
			if {[regexp {^[A-Za-z0-9._-]$} $char]} {
				append ret $char
			} else {
				set ascii [scan $char "%c"]
				append ret %[format "%02x" $ascii]
			}
		}

		return $ret
	}

	proc convert_html_entities {str} {
		set mappings [list "&" "&amp;" "<" "&lt;" ">" "&gt;" {"} "&quot;" {"} "Make VIM Happy"]

		set ret [string map $mappings $str]

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

			set name [::web::convert_html_entities $name]
			set currval [::web::convert_html_entities $currval]

			puts -nonewline "<input class=\"widget_${type}\" id=\"$name\" type=\"$type\" name=\"$name\" value=\"$currval\">"
		}

		proc password {name {default ""}} {
			return [entry $name $default password]
		}

		proc dropdown {name entries multiple {default ""} {size 1}} {
			set currval [::web::getarg $name $default]

			set name [::web::convert_html_entities $name]

			if {$size == 1} {
				set type "listbox"
			} else {
				set type "dropdown"
			}

			if {$multiple} {
				puts "<select class=\"widget_${type}\" id=\"$name\" name=\"$name\" size=\"$size\" multiple>"
			} else {
				puts "<select class=\"widget_${type}\" id=\"$name\" name=\"$name\" size=\"$size\">"
			}

			foreach entry $entries {
				set entry_val [lindex $entry 0]
				set entry_desc [lindex $entry 1]

				if {$entry_val == $currval} {
					set selected " selected"
				} else {
					set selected ""
				}

				set entry_val [::web::convert_html_entities $entry_val]
				set entry_desc [::web::convert_html_entities $entry_desc]

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

			set name [::web::convert_html_entities $name]
			set checkedvalue [::web::convert_html_entities $checkedvalue]

			puts -nonewline "<input class=\"widget_checkbox\" id=\"$name\" type=\"checkbox\" name=\"$name\" value=\"$checkedvalue\"${checked}> $text<br>"
		}

		proc button args {
			set useAjax 0
			if {[lindex $args 0] == "-ajax"} {
				set args [lrange $args 1 end]
				set useAjax 1
			}
			if {[llength $args] != 1 && [llength $args] != 2} {
				return -code error "wrong # args: should be \"button \[-ajax\] name ?value?\""
			}
			set name [lindex $args 0]
			set value [lindex $args 1]

			if {$value == ""} {
				set value $name
			}

			set name [::web::convert_html_entities $name]
			set value [::web::convert_html_entities $value]

			set ajaxpart ""
			if {$useAjax} {
				_createXMLHTTPObject

				set ajaxpart ""
			}

			puts "<input class=\"widget_button\" id=\"$name\" type=\"submit\" name=\"$name\" value=\"$value\"${ajaxpart}>"
		}

		proc imgbutton args {
			set useAjax 0
			if {[lindex $args 0] == "-ajax"} {
				set args [lrange $args 1 end]
				set useAjax 1
			}
			if {[llength $args] != 3 && [llength $args] != 4} {
				return -code error "wrong # args: should be \"imgbutton \[-ajax\] name imgname imgclass ?descr?\""
			}
			set name [lindex $args 0]
			set imgname [lindex $args 1]
			set imgclass  [lindex $args 2]
			set descr [lindex $args 3]

			set name [::web::convert_html_entities $name]
			set descr [::web::convert_html_entities $descr]

			set image [::web::image $imgname "" $imgclass 1]

			puts "<input class=\"widget_imgbutton\" id=\"$name\" type=\"image\" src=\"$image\" name=\"$name\" alt=\"$descr\" title=\"$descr\">"
		}

		proc _createXMLHTTPObject {} {
			if {![info exists ::request::WebApp_XMLHTTPObjectCreated]} {
				set ::request::WebApp_XMLHTTPObjectCreated 1
				puts {
<script type="text/javascript">
<!--
	function WebApp_sendEvent(url) {
		var WebApp_xmlHttpObject = null;

		// Try to get the right object for different browser
		try {
			// Firefox, Opera 8.0+, Safari
			WebApp_xmlHttpObject = new XMLHttpRequest();
		} catch (e) {
			// Internet Explorer
			try {
				WebApp_xmlHttpObject = new ActiveXObject("Msxml2.XMLHTTP");
			} catch (e) {
				WebApp_xmlHttpObject = new ActiveXObject("Microsoft.XMLHTTP");
			}
		}

		if (!WebApp_xmlHttpObject) {
			return;
		}

		WebApp_xmlHttpObject.onreadystatechange = function() {
			if (WebApp_xmlHttpObject.readyState != 4) {
				return;
			}

			if (WebApp_xmlHttpObject.status != 200) {
				return;
			}

			eval(WebApp_xmlHttpObject.responseText);
		}

		WebApp_xmlHttpObject.open("get", url);
		WebApp_xmlHttpObject.send(null);
	}
-->
</script>
				}
			}
		}
	}
}
