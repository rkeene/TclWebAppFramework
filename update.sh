#! /bin/sh

# Verify that we can actually do something.
svncmd="`which 'svn' 2>/dev/null`"
if [ -z "${svncmd}" -o ! -x "${svncmd}" ]; then
	echo "Could not find your subversion command." >&2
	which svn
	echo "Aborting." >&2
	exit 1
fi

# Find the script to restart the webserver
initscp=""
for testinitscp in /etc/rc.d/rc.httpd /etc/init.d/httpd /etc/rc.d/init.d/httpd /etc/init.d/apache error; do
	if [ "${testinitscp}" = "error" ]; then
		echo "Could not find a suitable Apache init script." >&2
		echo "You will need to restart your web server manually." >&2
		break
	fi
	if [ -x "${testinitscp}" ]; then
		initscp="${testinitscp}"
		break
	fi
done

# Verify that we are in the correct directory.
if [ ! -f "update.sh" -o ! -f "setup.tcl" -o ! -f "index.rvt" -o ! -d "packages" ]; then
	echo "Please run me from the webapp directory." >&2
	exit 1
fi

# Find the user to run the update as:
svnuser="`stat -c '%U' index.rvt 2>/dev/null`"
curruser="`whoami`"
if [ -z "${svnuser}" ]; then
	svnuser="`ls -l index.rvt 2>/dev/null | awk '{ print $3 }'`"
fi
if [ -z "${svnuser}" ]; then
	echo "Could not determine the user to run the updates as."
	echo "Please specify the user:"
	read svnuser
fi
if [ -z "${svnuser}" ]; then
	echo "Aborting." >&2
	exit 1
fi

# Do the update
if [ "${curruser}" = "${svnuser}" ]; then
	"${svncmd}" update || exit 1
else
	su "${svnuser}" -c "\"${svncmd}\" update" || exit 1
fi

echo "Updating complete."

# Do the restart, or tell the user to do so if we cannot.
if [ ! -z "${initscp}" ]; then
	"${initscp}" stop && \
	sleep 5
	"${initscp}" start || exit 1
	echo "Done."
else
	echo "Please restart your web server now."
fi

exit 0
