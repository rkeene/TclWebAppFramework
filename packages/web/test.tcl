#! /usr/bin/env tclsh

package require Tcl 8.5
package require tcltest

lappend auto_path [file join [file dirname [info script]] ..]

if {[llength $argv] != 0} {
	puts stderr "Usage: test.tcl"
}

package require web
package require debug

debug::logfile "-"

proc web_test_puts args {
	if {[llength $args] != 2 || [lindex $args 0] != "-nonewline"} {
		return [::tcl_puts {*}$args]
	}

	return ""
}

rename ::puts ::tcl_puts
rename web_test_puts ::puts

# Widgets
## Entry
::tcltest::test web-entry-0.0 "Widget Entry" -body {
	::web::widget::entry test
} -result {<input class="widget_text" id="test" name="test" type="text" value>}

::tcltest::test web-entry-0.1 "Widget Entry (old)" -body {
	::web::widget::entry test One testing
} -result {<input class="widget_testing" id="test" name="test" type="testing" value="One">}

::tcltest::test web-entry-0.2 "Widget Entry (new) 1" -body {
	::web::widget::entry test -noputs -default One
} -result {<input class="widget_text" id="test" name="test" type="text" value="One">}

::tcltest::test web-entry-0.3 "Widget Entry (new) 2" -body {
	::web::widget::entry test -noputs -default One -type testing
} -result {<input class="widget_testing" id="test" name="test" type="testing" value="One">}

::tcltest::test web-entry-0.4 "Widget Entry - Attributes 1" -body {
	::web::widget::entry test -noputs -default One -type testing -attribute id moreTest
} -result {<input class="widget_testing" id="moreTest" name="test" type="testing" value="One">}

::tcltest::test web-entry-0.5 "Widget Entry - Attributes 2" -body {
	::web::widget::entry test -noputs -default One -type testing -attribute id moreTest -attribute onClick "doSomething();"
} -result {<input class="widget_testing" id="moreTest" name="test" onClick="doSomething();" type="testing" value="One">}

::tcltest::test web-entry-0.6 "Widget Entry - Attributes 3" -body {
	::web::widget::entry test -noputs -default {[One]} -type testing -attribute id moreTest -attribute onClick "doSomething(a\[0\]);"
} -result {<input class="widget_testing" id="moreTest" name="test" onClick="doSomething(a[0]);" type="testing" value="[One]">}

## Password
::tcltest::test web-password-0.0 "Widget Password" -body {
	::web::widget::password test
} -result {<input class="widget_password" id="test" name="test" type="password" value>}

::tcltest::test web-password-0.1 "Widget Password (old)" -body {
	::web::widget::password test "Unknown"
} -result {<input class="widget_password" id="test" name="test" type="password" value="Unknown">}

::tcltest::test web-password-0.2 "Widget Password (new)" -body {
	::web::widget::password test -default "Unknown"
} -result {<input class="widget_password" id="test" name="test" type="password" value="Unknown">}

## Dropdown
::tcltest::test web-dropdown-0.0 "Widget Dropdown" -body {
	::web::widget::dropdown "test" [list [list a 0] [list b 1]] 0
} -result {<select class="widget_dropdown" id="test" name="test" size="1">
  <option value="a">0</option>
  <option value="b">1</option>
</select>}

::tcltest::test web-dropdown-0.0 "Widget Dropdown - Size" -body {
	::web::widget::dropdown "test" [list [list a 0] [list b 1]] 0 -size 5
} -result {<select class="widget_dropdown" id="test" name="test" size="5">
  <option value="a">0</option>
  <option value="b">1</option>
</select>}

::tcltest::test web-dropdown-0.2 "Widget Dropdown - Multiple" -body {
	::web::widget::dropdown "test" [list [list a 0] [list b 1]] 1
} -result {<select class="widget_dropdown" id="test" multiple name="test" size="1">
  <option value="a">0</option>
  <option value="b">1</option>
</select>}

::tcltest::test web-dropdown-0.3 "Widget Dropdown - Default Set (old)" -body {
	::web::widget::dropdown "test" [list [list a 0] [list b 1]] 0 "a"
} -result {<select class="widget_dropdown" id="test" name="test" size="1">
  <option value="a" selected>0</option>
  <option value="b">1</option>
</select>}

::tcltest::test web-dropdown-0.4 "Widget Dropdown - Default Set (new)" -body {
	::web::widget::dropdown "test" [list [list a 0] [list b 1]] 0 -default "a" -noputs
} -result {<select class="widget_dropdown" id="test" name="test" size="1">
  <option value="a" selected>0</option>
  <option value="b">1</option>
</select>}

## Listbox
::tcltest::test web-listbox-0.0 "Widget Listbox" -body {
	::web::widget::listbox "test" [list [list a 0] [list b 1]] 5 0
} -result {<select class="widget_listbox" id="test" name="test" size="5">
  <option value="a">0</option>
  <option value="b">1</option>
</select>}

::tcltest::test web-listbox-0.1 "Widget Listbox - Size" -body {
	::web::widget::listbox "test" [list [list a 0] [list b 1]] 1 0
} -result {<select class="widget_listbox" id="test" name="test" size="1">
  <option value="a">0</option>
  <option value="b">1</option>
</select>}

::tcltest::test web-listbox-0.2 "Widget Listbox - Multiple" -body {
	::web::widget::listbox "test" [list [list a 0] [list b 1]] 1 1
} -result {<select class="widget_listbox" id="test" multiple name="test" size="1">
  <option value="a">0</option>
  <option value="b">1</option>
</select>}

::tcltest::test web-listbox-0.3 "Widget Listbox - Default Set (old)" -body {
	::web::widget::listbox "test" [list [list a 0] [list b 1]] 1 0 "a"
} -result {<select class="widget_listbox" id="test" name="test" size="1">
  <option value="a" selected>0</option>
  <option value="b">1</option>
</select>}

::tcltest::test web-listbox-0.4 "Widget Listbox - Default Set (new)" -body {
	::web::widget::listbox "test" [list [list a 0] [list b 1]] 1 0 -default "a" -noputs
} -result {<select class="widget_listbox" id="test" name="test" size="1">
  <option value="a" selected>0</option>
  <option value="b">1</option>
</select>}

## Checkbox
::tcltest::test web-checkbox-0.0 "Widget Checkbox" -body {
	::web::widget::checkbox test 1 "Test"
} -result {<input class="widget_checkbox" id="test" name="test" type="checkbox" value="1"> Test</input><br>}

::tcltest::test web-checkbox-0.2 "Widget Checkbox (old) - Checked" -body {
	::web::widget::checkbox test 1 "Test" 1
} -result {<input checked class="widget_checkbox" id="test" name="test" type="checkbox" value="1"> Test</input><br>}

::tcltest::test web-checkbox-0.3 "Widget Checkbox (old) - Unchecked" -body {
	::web::widget::checkbox test 1 "Test" 2
} -result {<input class="widget_checkbox" id="test" name="test" type="checkbox" value="1"> Test</input><br>}

::tcltest::test web-checkbox-0.4 "Widget Checkbox (new) - Checked" -body {
	::web::widget::checkbox test 1 "Test" -default 1
} -result {<input checked class="widget_checkbox" id="test" name="test" type="checkbox" value="1"> Test</input><br>}

::tcltest::test web-checkbox-0.5 "Widget Checkbox (new) - Unchecked" -body {
	::web::widget::checkbox test 1 "Test" -default 2
} -result {<input class="widget_checkbox" id="test" name="test" type="checkbox" value="1"> Test</input><br>}

## Button
::tcltest::test web-button-0.0 "Widget Button" -body {
	::web::widget::button test
} -result {<input class="widget_button" id="test" name="test" type="submit" value="test">}

::tcltest::test web-button-0.1 "Widget Button - Value (old)" -body {
	::web::widget::button test "Click"
} -result {<input class="widget_button" id="test" name="test" type="submit" value="Click">}

::tcltest::test web-button-0.2 "Widget Button - Value (new)" -body {
	::web::widget::button test -value "Click" -noputs
} -result {<input class="widget_button" id="test" name="test" type="submit" value="Click">}

## ImgButton
::tcltest::test web-imgbutton-0.0 "Widget ImgButton" -body {
	set startDir [pwd]
	cd [file join [file dirname [info script]] .. ..]
	::web::widget::imgbutton test unknown icons
} -cleanup {
	cd $startDir
} -result {<input class="widget_imgbutton" id="test" name="test" src="/static/images/icons/unknown.png" type="image">}

::tcltest::test web-imgbutton-0.1 "Widget ImgButton - Description (old)" -body {
	set startDir [pwd]
	cd [file join [file dirname [info script]] .. ..]
	::web::widget::imgbutton test unknown icons "Click"
} -cleanup {
	cd $startDir
} -result {<input alt="Click" class="widget_imgbutton" id="test" name="test" src="/static/images/icons/unknown.png" title="Click" type="image">}

::tcltest::test web-imgbutton-0.2 "Widget ImgButton - Description (new)" -body {
	set startDir [pwd]
	cd [file join [file dirname [info script]] .. ..]
	::web::widget::imgbutton test unknown icons -desc "Click"
} -cleanup {
	cd $startDir
} -result {<input alt="Click" class="widget_imgbutton" id="test" name="test" src="/static/images/icons/unknown.png" title="Click" type="image">}

# Cleanup and exit
if {$::tcltest::numTests(Failed) != "0"} {
	exit 1
}

::tcltest::cleanupTests
