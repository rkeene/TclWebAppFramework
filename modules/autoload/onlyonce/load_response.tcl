###
## load_response ?arrayName?
##    Load any form variables passed to this page into an array.
##
##    arrayName - Name of the array to set.  Default is 'response'.
###

proc load_response {{arrayName response}} {
    upvar 1 $arrayName response

    array set response {}

    set work [var all]

    foreach {var elem} $work {
        if {[info exists response($var)]} {
            if {![info exists listified($var)]} {
                set response($var) [list $response($var) $elem]
                set listified($var) 1
            } else {
                lappend response($var) $elem
            }
        } else {
            set response($var) $elem
        }
    }
}
