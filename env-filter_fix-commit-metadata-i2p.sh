#!/bin/sh
# This script needs to be invoked as
#
# $ git filter-branch --env-filter "source PATH_TO_THIS_SCRIPT" HEAD
#
# because git treats the env-filter as a shell expression, not a command.
#

set_name_email() {
	D_NAME="$1"
	if [ -n "$2" ]; then D_EMAIL="$1"'@'"$2"; else D_EMAIL=""; fi
}

set_git_vars() {
	echo "$1" | {
		read x name date_1 date_2
		name=${name#<}
		name=${name%>}

		OLDIFS="$IFS"
		IFS="@"
		set_name_email $name
		IFS="$OLDIFS"

		echo export "$2"="'$D_NAME'"
		echo export "$3"="'$D_EMAIL'"
		echo export "$4"="'$date_1 $date_2'"
	}
}

eval "$(set_git_vars "$GIT_COMMITTER_NAME" GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL GIT_COMMITTER_DATE)"
eval "$(set_git_vars "$GIT_AUTHOR_NAME" GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_AUTHOR_DATE)"

#export GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL GIT_COMMITTER_DATE GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_AUTHOR_DATE
#export -p | grep GIT_

#git commit-tree "$@"
