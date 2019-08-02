#!/bin/bash
#
# Take the branch we are working on, create the patches, email out that we
# applied them, merge to the branch, and push the branch to the servers if we
# are online.


txtund=$(tput sgr 0 1)    # Underline
txtbld=$(tput bold)       # Bold
txtred=$(tput setaf 1)    # Red
txtgrn=$(tput setaf 2)    # Green
txtylw=$(tput setaf 3)    # Yellow
txtblu=$(tput setaf 4)    # Blue
txtpur=$(tput setaf 5)    # Purple
txtcyn=$(tput setaf 6)    # Cyan
txtwht=$(tput setaf 7)    # White
txtrst=$(tput sgr0)       # Text reset

FROM='<gregkh@linuxfoundation.org>'
TO=""
CC=""

# This should be a git tree that contains *only* Linus' tree
Linus_tree="${HOME}/linux/work/torvalds"

# turn to 1 if you want debugging
debug=0
#debug=1

if [ ${debug} -eq 1 ] ; then
	quiet=""
else
	quiet="-q"
fi

log()
{
	if [ ${debug} -eq 1 ] ; then
		echo "${txtpur}${@}${txtrst}"
	fi
}


author()
{
        first_author=""
        TXT=$2
        if [ ! -f $TXT ]
        then
                echo "$TXT is missing"
                exit 1
        fi
        author=""
        while read l
        do
		# skip the Message-ID: line so we don't send email to the wrong place
		#echo "$l"
		reply=$(echo "$l" | grep -a -i Message-ID:)
		if [ x"$reply" != x ]
		then
			continue
		fi

		# if this is the start of the diff, then it's time to stop looking
		diff=$(echo "$l" | grep -a "^---")
		if [ x"$diff" != x ]
		then
			log "diffstart!!!!!"
			break
		fi

                for x in $l
                do
                        a=$(echo "$x" | sed -n -e 's/.*<\(.*@[^>]*\).*/\1/p')
                        if [ x"$a" != x ]
                        then
                                if [ x"$author" == x ]
                                then
                                        author=$a
                                        first_author=$a
                                else
                                        author="$author $a"
                                fi
                        fi
                done
        done < $TXT
        author=$(echo "$author" | tr ' ' '\n' | grep -a -v "$first_author" |
                sort | uniq)
        author="$first_author $author"
        eval $1=$(echo $author | sed -e 's/ /,/g')
        if [ x"$3" != x ]
        then
                eval $3=$first_author
        fi
}

reply()
{
	PATCH=$1
	log "PATCH=$PATCH"
	SUBJECT=`grep -a "Subject:" $PATCH | sed s/Subject\:\ //`
	MESSAGE_ID=`grep -a -i "^Message-ID:" $PATCH | cut -f 2 -d ' ' | cut -f 2 -d '<' | cut -f 1 -d '>'`
	author AUTHOR $1 FIRST_AUTHOR
#	echo "author said $AUTHOR"
#	echo "first_author said $FIRST_AUTHOR"
	if [ x"$AUTHOR" == "x" ]
	then
		echo "nobody to notify"
		exit 0
	fi
	to=""
	for i in $(echo "$AUTHOR" | sed -e 's/,/ /g')
	do
		if ! echo "$TO" | grep -a "$i"
		then
			to=$to" -to $i"
		fi
	done
	if [ x"$cc" != x ]
	then
		cc="-cc $cc"
	fi

	CHARSET=$(guess-charset "$PATCH")
	if test "x$CHARSET" = "ANSI_X3.4-1968"; then
		CHARSET=
	else
		CHARCMD="-charset=$CHARSET"
	fi

	ID=`make_message_id`

#	echo "makemail -to $AUTHOR -from=$FROM -subject=\"patch $PATCH added to gregkh tree\" -date=\"$(date -R)\" -reply_to=$MESSAGE_ID -message=$ID $CHARCMD"
	(
		echo
		echo "This is a note to let you know that I've just added the patch titled"
		echo
		echo "    $SUBJECT"
		echo
		echo "to my ${TREE} git tree which can be found at"
		echo "    git://git.kernel.org/pub/scm/linux/kernel/git/gregkh/${TREE}.git"
		echo "in the ${TREE}-${BRANCH} branch."
		echo
		echo "The patch will show up in the next release of the linux-next tree"
		echo "(usually sometime within the next 24 hours during the week.)"
		echo
		if [ "${BRANCH}" = "next" ] ; then
			echo "The patch will also be merged in the next major kernel release"
			echo "during the merge window."
		else if [ "${BRANCH}" = "linus" ]; then
			echo "The patch will hopefully also be merged in Linus's tree for the"
			echo "next -rc kernel release."
		else
			echo "The patch will be merged to the ${TREE}-next branch sometime soon,"
			echo "after it passes testing, and the merge window is open."
		fi
		fi
		echo
		echo "If you have any questions about this process, please let me know."
		echo
		echo
		cat $PATCH
		echo
	) |
	makemail -to "$AUTHOR" -from="$FROM" \
		-subject="patch \"$SUBJECT\" added to ${TREE}-${BRANCH}" \
		-date="$(date -R)" \
		-reply_to="$MESSAGE_ID" \
		-message_id="$ID" \
		"$CHARCMD" | \
	~/bin/msmtp-enqueue.sh $to
}

# Verify we have signed-off-by correct for everything set up properly
# Thanks to Stephen Rothwell <sfr@canb.auug.org.au> for this chunk of code
verify_signedoff()
{
	error=false
	for c in $(git rev-list --no-merges ${TREE}-${BRANCH}..HEAD); do
		ae=$(git log -1 --format='%ae' "$c")
		aE=$(git log -1 --format='%aE' "$c")
		an=$(git log -1 --format='%an' "$c")
		aN=$(git log -1 --format='%aN' "$c")
		ce=$(git log -1 --format='%ce' "$c")
		cE=$(git log -1 --format='%cE' "$c")
		cn=$(git log -1 --format='%cn' "$c")
		cN=$(git log -1 --format='%cN' "$c")
		sob=$(git log -1 --format='%b' "$c" | grep -i '^[[:space:]]*Signed-off-by:')

		am=false
		cm=false
		grep -i -q "<$ae>" <<<"$sob" ||
			grep -i -q "<$aE>" <<<"$sob" ||
			grep -i -q ":[[:space:]]*$an[[:space:]]*<" <<<"$sob" ||
			grep -i -q ":[[:space:]]*$aN[[:space:]]*<" <<<"$sob" ||
			am=true
		grep -i -q "<$ce>" <<<"$sob" ||
			grep -i -q "<$cE>" <<<"$sob" ||
			grep -i -q ":[[:space:]]*$cn[[:space:]]*<" <<<"$sob" ||
			grep -i -q ":[[:space:]]*$cN[[:space:]]*<" <<<"$sob" ||
			cm=true

		if "$am" || "$cm"; then
			printf "Commit %s\n" "$c"
			"$am" && printf "\tauthor SOB missing\n"
			"$cm" && printf "\tcommitter SOB missing\n"
			printf "\t%s %s\n\t%s\n" "$ae" "$ce" "$sob"
			error=true
		fi
	done
	if "$error"; then
		echo "Errors in tree with signed-off-by, please fix!"
		exit 1
	fi
}

# Verify we have fixes correct
# Thanks to Stephen Rothwell <sfr@canb.auug.org.au> for this chunk of code

split_re='^([Cc][Oo][Mm][Mm][Ii][Tt])?[[:space:]]*([[:xdigit:]]{5,})([[:space:]]*)(.*)$'
nl=$'\n'
tab=$'\t'

# Strip the leading and training spaces from a string
strip_spaces()
{
	[[ "$1" =~ ^[[:space:]]*(.*[^[:space:]])[[:space:]]*$ ]]
	echo "${BASH_REMATCH[1]}"
}

verify_fixes()
{
	error=0
	commits=$(git rev-list --no-merges -i --grep='^[[:space:]]*Fixes:' "${TREE}-${BRANCH}..HEAD")
	if [ -z "$commits" ]; then
	        return 0
	fi

	for c in $commits; do

		commit_log=$(git log -1 --format='%h ("%s")' "$c")
			commit_msg="In commit

  $commit_log

"

		fixes_lines=$(git log -1 --format='%B' "$c" |
				grep -i '^[[:space:]]*Fixes:')

		while read -r fline; do
			[[ "$fline" =~ ^[[:space:]]*[Ff][Ii][Xx][Ee][Ss]:[[:space:]]*(.*)$ ]]
			f="${BASH_REMATCH[1]}"
			fixes_msg="Fixes tag

  $fline

has these problem(s):

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
					msg="${msg:+${msg}${nl}}  - leading word '$first' unexpected"
				fi
				if [ -z "$subject" ]; then
					msg="${msg:+${msg}${nl}}  - missing subject"
				elif [ -z "$spaces" ]; then
					msg="${msg:+${msg}${nl}}  - missing space between the SHA1 and the subject"
				fi
			else
				printf '%s%s  - %s\n' "$commit_msg" "$fixes_msg" 'No SHA1 recognised'
				commit_msg=''
				error=1
				continue
			fi
			if ! git rev-parse -q --verify "$sha" >/dev/null; then
				printf '%s%s  - %s\n' "$commit_msg" "$fixes_msg" 'Target SHA1 does not exist'
				commit_msg=''
				error=1
				continue
			fi

			if [ "${#sha}" -lt 12 ]; then
				msg="${msg:+${msg}${nl}}  - SHA1 should be at least 12 digits long${nl}    Can be fixed by setting core.abbrev to 12 (or more) or (for git v2.11${nl}    or later) just making sure it is not set (or set to \"auto\")."
			fi
			# reduce the subject to the part between () if there
			if [[ "$subject" =~ ^\((.*)\) ]]; then
				subject="${BASH_REMATCH[1]}"
			elif [[ "$subject" =~ ^\((.*) ]]; then
				subject="${BASH_REMATCH[1]}"
				msg="${msg:+${msg}${nl}}  - Subject has leading but no trailing parentheses"
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
				msg="${msg:+${msg}${nl}}  - Subject has leading but no trailing quotes"
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
				msg="${msg:+${msg}${nl}}  - Subject does not match target commit subject${nl}    Just use${nl}${tab}git log -1 --format='Fixes: %h ("%s")'"
			fi
			lsha=$(cd "$Linus_tree" && git rev-parse -q --verify "$sha")
			if [ -z "$lsha" ]; then
				count=$(git rev-list --count "$sha".."$c")
				if [ "$count" -eq 0 ]; then
					msg="${msg:+${msg}${nl}}  - Target is not an ancestor of this commit"
				fi
			fi

			if [ "$msg" ]; then
				printf '%s%s%s\n' "$commit_msg" "$fixes_msg" "$msg"
				commit_msg=''
				error=1
			fi
		done <<< "$fixes_lines"
	done

	#echo "ERROR = ${error}\n"

	if [ ${error} -eq 1 ] ; then
		exit 1
	fi
}

# we need to be either on the 'work-next' branch, or the 'work-linus' branch in
# order to work properly, error out if we are on something else.
#CURRENT_BRANCH=`git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/'`
CURRENT_BRANCH=`git symbolic-ref --short -q HEAD`
BRANCH=""
if [ "$CURRENT_BRANCH" = "work-next" ] ; then
	BRANCH="next"
else if [ "$CURRENT_BRANCH" = "work-linus" ] ; then
	BRANCH="linus"
else if [ "$CURRENT_BRANCH" = "work-testing" ] ; then
	BRANCH="testing"
fi
fi
fi

if [ "$BRANCH" = "" ] ; then
	echo "ERROR!!!"
	echo "Right now you are on the \"$CURRENT_BRANCH\" branch."
	echo "You need to be on either \"work-next\" or \"work-linus\" or \"work-testing\""
	echo "branch for things to work properly."
	exit
fi
#echo "BRANCH=$BRANCH"

# look and see if there are any patches in this dir first, error out if so, we
# don't want to accidentally send them out twice
OLD_PATCH=`ls 0*.patch 2>/dev/null | head -n 1`
if [ "${OLD_PATCH}" != "" ] ; then
	echo -n "${txtcyn}WARNING:${txtrst}"
	echo " ${txtylw}There are old patches still in the directory:${txtrst}"
	for P in 0*.patch; do
		echo "	${P}"
	done
	echo "${txtylw}I will clean them up if you don't stop the script right now.${txtrst}"
	echo -n "[ret] to continue"
	read
	rm 0*.patch
	#exit
fi

PWD=`pwd`
TREE=`basename ${PWD}`

# generate the patches
log "${TREE}-${BRANCH}"
#git format-patch ${quiet} -k -M -N ${TREE}-${BRANCH}..HEAD
# for now let's see the patches being created.
git format-patch -k -M -N ${TREE}-${BRANCH}..HEAD

# verify that we actually generated some patches
PATCH=`ls 0*.patch 2>/dev/null | head -n 1`
if [ "${PATCH}" = "" ] ; then
	echo -n "${txtred}${txtbld}ERROR:${txtrst}"
	echo " ${txtylw}No patches were generated, are you sure you actually committed anything here?${txtrst}"
	exit
fi

echo -n "${txtylw}Verifying \"Signed-off-by:\"...${txtrst}		"
verify_signedoff
echo "${txtgrn}PASSED${txtrst}"

echo -n "${txtylw}Verifying \"Fixes:\"...${txtrst}			"
verify_fixes
echo "${txtgrn}PASSED${txtrst}"

# send out emails
#../added-to-${TREE}-${BRANCH} 0*.patch
echo -n "${txtylw}Sending emails...${txtrst}			"
for patch_file in `ls 0*.patch`
do
	reply $patch_file
	log "acknowledged $patch_file"
	log "-----------------------------------------------"
done
echo "${txtgrn}DONE${txtrst}"


echo -n "${txtylw}Merging patches back to branch ${txtcyn}${BRANCH}${txtrst}...${txtrst}	"

# merge the patches back to the branch
git checkout ${quiet} ${TREE}-${BRANCH} && git merge ${quiet} work-${BRANCH}

# if something goes wrong, exit
if [ $? -ne 0 ] ; then
	exit
fi
echo "${txtgrn}DONE${txtrst}"

ONLINE=`gregkh_machine_online`
# Only push if we have a network connection
if [ "$ONLINE" = "1" ] ; then
	for remote in `git remote`
	do
		echo "${txtylw}pushing to${txtrst} ${txtcyn}${remote}${txtrst}"
		git push ${quiet} ${remote} ${TREE}-${BRANCH}
	done
fi

# now go back to the original branch so that we can continue to work
git checkout ${quiet} work-${BRANCH}
