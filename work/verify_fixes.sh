#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) 2019 Stephen Rothwell <sfr@canb.auug.org.au>
# Copyright (C) 2019 Greg Kroah-Hartman <gregkh@linuxfoundation.org>
#
# Verify that the "Fixes:" tag is correct in a kernel commit
#
# usage:
#	verify_fixes.sh GIT_RANGE
#
# To test just the HEAD commit do:
#	verify_fixes.sh HEAD^..HEAD
#
#
# Thanks to Stephen Rothwell <sfr@canb.auug.org.au> for the majority of this code
#

# Only thing you might want to change here, the location of where Linus's git
# tree is on your system:
Linus_tree="/home/gregkh/linux/work/torvalds/"

##########################################
# No need to touch anything below here

split_re='^([Cc][Oo][Mm][Mm][Ii][Tt])?[[:space:]]*([[:xdigit:]]{5,})([[:space:]]*)(.*)$'
nl=$'\n'
tab=$'\t'

help()
{
	echo "error, git range not found"
	echo "usage:"
	echo "	$0 GIT_RANGE"
	exit 1
}

# Strip the leading and training spaces from a string
strip_spaces()
{
	[[ "$1" =~ ^[[:space:]]*(.*[^[:space:]])[[:space:]]*$ ]]
	echo "${BASH_REMATCH[1]}"
}

verify_fixes()
{
	git_range=$1
	error=0
	commits=$(git rev-list --no-merges -i --grep='^[[:space:]]*Fixes:' "${git_range}")
	if [ -z "$commits" ]; then
	        return 0
	fi

	for c in $commits; do

		commit_log=$(git log -1 --format='%h ("%s")' "$c")
#			commit_msg="In commit:
#	$commit_log
#"
			commit_msg="Commit: $commit_log
"

		fixes_lines=$(git log -1 --format='%B' "$c" |
				grep -i '^[[:space:]]*Fixes:')

		while read -r fline; do
			[[ "$fline" =~ ^[[:space:]]*[Ff][Ii][Xx][Ee][Ss]:[[:space:]]*(.*)$ ]]
			f="${BASH_REMATCH[1]}"
#			fixes_msg="	Fixes tag:
#		$fline
#	Has these problem(s):
#"
			fixes_msg="	Fixes tag: $fline
	Has these problem(s):
"
			sha=
			subject=
			msg=

			if [[ "$f" =~ $split_re ]]; then
				first="${BASH_REMATCH[1]}"
				sha="${BASH_REMATCH[2]}"
				spaces="${BASH_REMATCH[3]}"
				subject="${BASH_REMATCH[4]}"
				if [ "$first" ]; then
					msg="${msg:+${msg}${nl}}${tab}${tab}- leading word '$first' unexpected"
				fi
				if [ -z "$subject" ]; then
					msg="${msg:+${msg}${nl}}${tab}${tab}- missing subject"
				elif [ -z "$spaces" ]; then
					msg="${msg:+${msg}${nl}}${tab}${tab}- missing space between the SHA1 and the subject"
				fi
			else
				printf '%s%s\t\t- %s\n' "$commit_msg" "$fixes_msg" 'No SHA1 recognised'
				commit_msg=''
				error=1
				continue
			fi
			if ! git rev-parse -q --verify "$sha" >/dev/null; then
				printf '%s%s\t\t- %s\n' "$commit_msg" "$fixes_msg" 'Target SHA1 does not exist'
				commit_msg=''
				error=1
				continue
			fi

			if [ "${#sha}" -lt 12 ]; then
				msg="${msg:+${msg}${nl}}${tab}${tab}- SHA1 should be at least 12 digits long${nl}${tab}${tab}  Can be fixed by setting core.abbrev to 12 (or more) or (for git v2.11${nl}${tab}${tab}  or later) just making sure it is not set (or set to \"auto\")."
			fi
			# reduce the subject to the part between () if there
			if [[ "$subject" =~ ^\((.*)\) ]]; then
				subject="${BASH_REMATCH[1]}"
			elif [[ "$subject" =~ ^\((.*) ]]; then
				subject="${BASH_REMATCH[1]}"
				msg="${msg:+${msg}${nl}}${tab}${tab}- Subject has leading but no trailing parentheses"
			fi

			# strip matching quotes at the start and end of the subject
			# the unicode characters in the classes are
			# U+201C LEFT DOUBLE QUOTATION MARK
			# U+201D RIGHT DOUBLE QUOTATION MARK
			# U+2018 LEFT SINGLE QUOTATION MARK
			# U+2019 RIGHT SINGLE QUOTATION MARK
			re1=$'^[\"\u201C](.*)[\"\u201D]$'
			re2=$'^[\'\u2018](.*)[\'\u2019]$'
			re3=$'^[\"\'\u201C\u2018](.*)$'
			if [[ "$subject" =~ $re1 ]]; then
				subject="${BASH_REMATCH[1]}"
			elif [[ "$subject" =~ $re2 ]]; then
				subject="${BASH_REMATCH[1]}"
			elif [[ "$subject" =~ $re3 ]]; then
				subject="${BASH_REMATCH[1]}"
				msg="${msg:+${msg}${nl}}${tab}${tab}- Subject has leading but no trailing quotes"
			fi

			subject=$(strip_spaces "$subject")

			target_subject=$(git log -1 --format='%s' "$sha")
			target_subject=$(strip_spaces "$target_subject")

			# match with ellipses
			case "$subject" in
			*...)	subject="${subject%...}"
				target_subject="${target_subject:0:${#subject}}"
				;;
			...*)	subject="${subject#...}"
				target_subject="${target_subject: -${#subject}}"
				;;
			*\ ...\ *)
				s1="${subject% ... *}"
				s2="${subject#* ... }"
				subject="$s1 $s2"
				t1="${target_subject:0:${#s1}}"
				t2="${target_subject: -${#s2}}"
				target_subject="$t1 $t2"
				;;
			esac
			subject=$(strip_spaces "$subject")
			target_subject=$(strip_spaces "$target_subject")

			if [ "$subject" != "${target_subject:0:${#subject}}" ]; then
				msg="${msg:+${msg}${nl}}${tab}${tab}- Subject does not match target commit subject${nl}${tab}${tab}  Just use${nl}${tab}${tab}${tab}git log -1 --format='Fixes: %h (\"%s\")'"
			fi
			lsha=$(cd "$Linus_tree" && git rev-parse -q --verify "$sha")
			if [ -z "$lsha" ]; then
				count=$(git rev-list --count "$sha".."$c")
				if [ "$count" -eq 0 ]; then
					msg="${msg:+${msg}${nl}}${tab}${tab}- Target is not an ancestor of this commit"
				fi
			fi

			if [ "$msg" ]; then
				printf '%s%s%s\n' "$commit_msg" "$fixes_msg" "$msg"
				commit_msg=''
				error=1
			fi
		done <<< "$fixes_lines"
	done

	if [ ${error} -eq 1 ] ; then
		exit 1
	fi
}

git_range=$1

if [ "${git_range}" == "" ] ; then
	help
fi

verify_fixes "${git_range}"
exit 0
