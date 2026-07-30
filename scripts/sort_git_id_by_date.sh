#!/bin/bash
#
# Note, clanker created, keep around for the idea, don't rely on this, it's wrong in a few places...
#
#
# sort_git_id_by_date.sh - sort a list of git commit ids by the order in
# which they were written to the git repository this script resides in
# (committer date, oldest first).
#
# Usage: sort_git_id_by_date.sh <file-with-commit-ids>
#        sort_git_id_by_date.sh -   (read ids from stdin)

set -o pipefail

if [ $# -ne 1 ]; then
	echo "Usage: $0 <file-with-commit-ids>" >&2
	exit 1
fi

input=$1
if [ "$input" != "-" ] && [ ! -r "$input" ]; then
	echo "Error: cannot read file '$input'" >&2
	exit 1
fi

# The repository is the one the script lives in, not the caller's cwd.
script_dir=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)

if ! git -C "$script_dir" rev-parse --git-dir >/dev/null 2>&1; then
	echo "Error: '$script_dir' is not inside a git repository" >&2
	exit 1
fi

tmp=$(mktemp) || exit 1
trap 'rm -f "$tmp"' EXIT

status=0
while read -r id _; do
	# skip blank lines and comments
	case "$id" in
	""|\#*) continue ;;
	esac

	if ! ts=$(git -C "$script_dir" show -s --format=%ct "$id" -- 2>/dev/null); then
		echo "Warning: skipping unknown commit id '$id'" >&2
		status=1
		continue
	fi
	printf '%s %s\n' "$ts" "$id"
done < <(cat -- "$input") > "$tmp"

sort -n -k1,1 "$tmp" | cut -d' ' -f2

exit $status
