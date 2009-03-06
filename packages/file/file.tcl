package provide file 0.1

package require user
package require db
package require wa_uuid

wa_uuid::register 30 file

namespace eval file {
	# Name: ::file::create
	# Args:
	#	name		Name of file to create.
	# Rets: FileID, 0 on failure.
	# Stat: In progress.
	proc create {name} {
		set ret 0
		catch {
			set id [wa_uuid::gen file]
			set uid [user::getuid]

			file mkdir local/static/files/$id/

			set dbsetret [db::set -dbname file -field id $id -field name $name -field write $uid]
			if {$dbsetret} {
				set ret $id
			}
		}

		return $ret
	}

	# Name: ::file::glob
	# Args:
	#	?glob?		Pattern to glob for
	#	?perm?		Permissions required to return
	#			(ANY, READ, WRITE)
	# Rets: A list of the following list {id name size} that matches the
	#	requested glob and permissions.
	# Stat: In progress.
	proc glob {{glob *} {perm ANY}} {
	}

	# Name: ::file::delete
	# Args:
	#	id		Id of file to delete
	# Rets: 1 on success, 0 otherwise
	# Stat: In progress.
	proc delete {id} {
		
	}

	# Name: ::file::writable
	# Args:
	#	id		Id of file to determine writability
	#	?uid?		UID to check as (defaults to current)
	# Rets:
	# Stat: In progress.
	proc writable {id {uid ""}} {
		if {$uid == ""} {
			set uid [user::getuid]
		}
/I STOPPED HERE TO FIX WINDOWS/
		set writers [db::get -dbname file -field write -where id=$id]
	}

	# Name: ::file
	# Args:
	# Rets:
	# Stat: In progress.
	proc BLAH {} {
	}

	# Name: ::file
	# Args:
	# Rets:
	# Stat: In progress.
	proc BLAH {} {
	}

	# Name: ::file
	# Args:
	# Rets:
	# Stat: In progress.
	proc BLAH {} {
	}

}
