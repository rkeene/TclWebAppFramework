#! /usr/bin/env tclsh

package require imweb

page .
page .secondpage

input .text
input .pass -type password
button .ok -type submit -command {
	.secondpage go
}

button .cancel {
	.text set ""
	.pass set ""
}

button .secondpage.done -type submit -command {
	. go
}

layout . {
	.text .pass
	.ok .cancel
}

layout .secondpage {
	.secondpage.done
}

. go
