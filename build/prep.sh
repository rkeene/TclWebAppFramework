#! /bin/bash

# Generate the documentation
(
	exit 0
	cd doc || exit 1
	rm -f userguide.pdf webapp.pdf
	lyx2pdf userguide.lyx
	lyx2pdf webapp.lyx
)

# Delete anything we may have stored in local
rm -rf local
mkdir -p local/modules/load local/static local/modules/load/onlyonce

# Create a dummy configuration.
cat <<EOF >local/modules/load/onlyonce/siteconfig.tcl
namespace eval ::config {
	set db(unconfigured) 1
}
EOF

# Delete the "update.sh", it's only for people using SVN versions.
rm -f update.sh

# Delete any directories named "work", they hold working documents
find . -type d -name work -print0 | xargs -0 rm -rf
find . -type f -name .cvsignore -print0 | xargs -0 rm -rf

# Test databases for sanity
(
	cd packages/db || exit 1

	"./do-tests.sh" || exit 1

	exit 0
) || exit 1

packages/web/test.tcl || exit 1

# Delete test databases
rm -f packages/db/test.{mk4,sqlite}
rm -f packages/db/do-tests.sh

exit 0
