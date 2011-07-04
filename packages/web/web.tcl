package provide web 0.4

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
		proc _handle_args {cmd olddefinition options_list argsval} {
			set mandatory_list [list]
			set arg_usage_list [list]
			foreach def $olddefinition {
				set var [lindex $def 0]

				if {[llength $def] == 2} {
					set val [lindex $def 1]

					set to_set($var) $val

					lappend arg_usage_list "?${var}?"
				} else {
					lappend mandatory_list $var

					lappend arg_usage_list $var
				}
			}

			set new_argsval [lrange $argsval [llength $mandatory_list] end]

			if {[string index [lindex $new_argsval 0] 0] != "-" && $olddefinition != "" && [llength $argsval] <= [llength $olddefinition]} {
				# Use old definition

				if {[llength $argsval] < [llength $mandatory_list]} {
					return -code error "wrong # args: should be \"$cmd [join $arg_usage_list " "]\""
				}

				set olddefinition [lrange $olddefinition 0 [expr {[llength $argsval] - 1}]]

				foreach def $olddefinition argval $argsval {
					set var [lindex $def 0]

					set to_set($var) $argval
				}
			} else {
				# Use new definition
				if {[llength $argsval] < [llength $mandatory_list]} {
					return -code error "wrong # args: should be \"$cmd [join $mandatory_list " "] ?option ...?\""
				}

				foreach argval [lrange $argsval 0 [expr {[llength $mandatory_list] - 1}]] mandatory $mandatory_list {
					set to_set($mandatory) $argval
				}

				set argsval $new_argsval

				foreach optioninfo $options_list {
					set option [lindex $optioninfo 0]
					if {[string index $option end] == "*"} {
						set option [string range $option 0 end-1]
					}

					set optionsinfo($option) $optioninfo
				}

				set options_help [join [array names optionsinfo] ", "]

				for {set idx 0} {$idx < [llength $argsval]} {incr idx} {
					set argval [lindex $argsval $idx]

					if {![info exists optionsinfo($argval)]} {
						return -code error "bad option \"$argval\": must be $options_help"
					}

					set option [lindex $optionsinfo($argval) 0]
					set option_args [lrange $optionsinfo($argval) 1 end]

					if {[string index $option end] == "*"} {
						set option [string range $option 1 end-1]

						set update_mode "lappend"
					} else {
						set option [string range $option 1 end]

						set update_mode "set"
					}

					set option_arg_set [list]
					foreach option_arg $option_args {
						incr idx
						set option_argval [lindex $argsval $idx]

						lappend option_arg_set $option_argval
					}


					if {[llength $option_arg_set] == 1} {
						set var "$option"
					} else {
						set var "${option}([lrange $option_arg_set 0 end-1])"
						set option_arg_set [lindex $option_arg_set end]
					}

					$update_mode to_set($var) $option_arg_set
				}
			}

			foreach {var val} [array get to_set] {
				uplevel 1 [list set $var $val]
			}

			return
		}

		proc _build_html_widget {entity attrs_list} {
			set html "<$entity"

			array set attrs $attrs_list

			foreach attr [lsort -dictionary [array names attrs]] {
				set val $attrs($attr)

				if {$val == ""} {
					append html " $attr"
				} else {
					append html " $attr=\"[::web::convert_html_entities $val]\""
				}
			}

			append html ">"

			return $html
		}

		proc entry args {
			array set attribute [list]
			_handle_args entry {name {default ""} {type "text"}} [list "-default value" "-type value" "-attribute value value" "-noputs"] $args

			set currval [::web::getarg $name $default]

			set attrs(id) $name
			set attrs(class) "widget_${type}"
			set attrs(type) $type
			set attrs(name) $name
			set attrs(value) $currval
			array set attrs [array get attribute]

			set html [_build_html_widget "input" [array get attrs]]

			if {![info exists noputs]} {
				puts -nonewline $html
			}

			return $html
		}

		proc password {name args} {
			if {[llength $args] == 1} {
				set args [list "-default" [lindex $args 0]]
			}

			set cmd $args
			set cmd [linsert $cmd 0 entry $name -type password]

			return [eval $cmd]
		}

		proc dropdown args {
			array set attribute [list]
			_handle_args dropdown {name entries multiple {default ""} {size 1} {type "dropdown"}} [list "-default value" "-type value" "-size value" "-attribute value value" "-noputs"] $args

			set currval [::web::getarg $name $default]

			set attrs(id) $name
			set attrs(class) "widget_${type}"
			set attrs(name) $name
			set attrs(size) $size
			array set attrs [array get attribute]

			if {$multiple} {
				set attrs(multiple) ""
			}

			set html [_build_html_widget "select" [array get attrs]]
			append html "\n"

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

				append html "  <option value=\"$entry_val\"${selected}>$entry_desc</option>\n"
			}

			append html "</select>"

			if {![info exists noputs]} {
				puts -nonewline $html
			}

			return $html
		}

		proc listbox {name entries size multiple args} {
			if {[llength $args] == 1} {
				set args [list "-default" [lindex $args 0]]
			}

			lappend args -size $size
			lappend args -type listbox

			set cmd $args
			set cmd [linsert $cmd 0 dropdown $name $entries $multiple]

			return [eval $cmd]
		}

		proc checkbox args {
			array set attribute [list]
			_handle_args checkbox {name checkedvalue text {default ""}} [list "-default value" "-attribute value value" "-noputs"] $args

			set currval [::web::getarg $name $default]

			set attrs(id) $name
			set attrs(class) "widget_checkbox"
			set attrs(type) checkbox
			set attrs(name) $name
			set attrs(value) $checkedvalue
			array set attrs [array get attribute]

			if {$currval == $checkedvalue} {
				set attrs(checked) ""
			}

			set html [_build_html_widget "input" [array get attrs]]
			append html " $text</input><br>"

			if {![info exists noputs]} {
				puts -nonewline $html
			}

			return $html
		}

		proc button args {
			array set attribute [list]
			_handle_args button {name {value ""}} [list "-value value" "-attribute value value" "-noputs" "-ajax"] $args

			if {[info exists ajax]} {
				set useAjax 1
			} else {
				set useAjax 0
			}

			if {$value == ""} {
				set value $name
			}

			set attrs(id) $name
			set attrs(class) "widget_button"
			set attrs(type) submit 
			set attrs(name) $name
			set attrs(value) $value
			array set attrs [array get attribute]

			if {$useAjax} {
				set html [_createXMLHTTPObject]
			} else {
				set html ""
			}

			append html [_build_html_widget "input" [array get attrs]]

			if {![info exists noputs]} {
				puts -nonewline $html
			}

			return $html
		}

		proc imgbutton args {
			array set attribute [list]
			_handle_args imgbutton {name imgname imgclass {desc ""}} [list "-desc value" "-attribute value value" "-noputs" "-ajax"] $args

			if {[info exists ajax]} {
				set useAjax 1
			} else {
				set useAjax 0
			}

			set image [::web::image $imgname "" $imgclass 1]

			set attrs(id) $name
			set attrs(class) "widget_imgbutton"
			set attrs(type) image
			set attrs(src) $image
			set attrs(name) $name

			if {$desc != ""} {
				set attrs(alt) $desc
				set attrs(title) $desc
			}

			array set attrs [array get attribute]

			if {$useAjax} {
				set html [_createXMLHTTPObject]
			} else {
				set html ""
			}

			append html [_build_html_widget "input" [array get attrs]]

			if {![info exists noputs]} {
				puts -nonewline $html
			}

			return $html
		}

		proc _createXMLHTTPObject {} {
			if {[info exists ::request::WebApp_XMLHTTPObjectCreated]} {
				return ""
			}

			set ::request::WebApp_XMLHTTPObjectCreated 1
			return {
<script type="text/javascript">
<!--
	function WebApp_sendEvent(url) {
		var WebApp_xmlHttpObject = null;
		var e;

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
