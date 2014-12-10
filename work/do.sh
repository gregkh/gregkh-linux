#!/bin/bash
#
# Take the branch we are working on, create the patches, email out that we
# applied them, merge to the branch, and push the branch to the servers if we
# are online.



FROM='<gregkh@linuxfoundation.org>'
TO=""
CC=""

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
		reply=$(echo "$l" | grep -i Message-ID:)
		if [ x"$reply" != x ]
		then
			continue
		fi

		# if this is the start of the diff, then it's time to stop looking
		diff=$(echo "$l" | grep "^---")
		if [ x"$diff" != x ]
		then
			#echo "diffstart!!!!!"
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
        author=$(echo "$author" | tr ' ' '\n' | grep -v "$first_author" |
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
	echo "PATCH=$PATCH"
	SUBJECT=`grep "Subject:" $PATCH | sed s/Subject\:\ //`
	MESSAGE_ID=`grep -i "^Message-ID:" $PATCH | cut -f 2 -d ' ' | cut -f 2 -d '<' | cut -f 1 -d '>'`
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
		if ! echo "$TO" | grep "$i"
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
			echo "after it pasts testing, and the merge window is open."
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


# we need to be either on the 'work-next' branch, or the 'work-linus' branch in
# order to work properly, error out if we are on something else.
CURRENT_BRANCH=`git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/'`
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
echo "BRANCH=$BRANCH"

# look and see if there are any patches in this dir first, error out if so, we
# don't want to accidentally send them out twice
OLD_PATCH=`ls 0*.patch 2>/dev/null | head -n 1`
if [ "${OLD_PATCH}" != "" ] ; then
	echo "WARNING: There are old patches still in the directory:"
	for P in 0*.patch; do
		echo "	${P}"
	done
	echo ""
	echo "I will clean them up if you don't stop the script right now."
	echo -n "[ret] to continue"
	read
	rm 0*.patch
	#exit
fi

PWD=`pwd`
TREE=`basename ${PWD}`

# generate the patches
git format-patch -k -M -N ${TREE}-${BRANCH}

# verify that we actually generated some patches
PATCH=`ls 0*.patch 2>/dev/null | head -n 1`
if [ "${PATCH}" = "" ] ; then
	echo "ERROR!!!"
	echo "No patches were generated, are you sure you actually committed anything here?"
	exit
fi

# send out emails
#../added-to-${TREE}-${BRANCH} 0*.patch
for patch_file in `ls 0*.patch`
do
	reply $patch_file
	echo "acknowledged $patch_file"
	echo "-----------------------------------------------"
	echo
done


# merge the patches back to the branch
git checkout ${TREE}-${BRANCH} && git merge work-${BRANCH}

# if something goes wrong, exit
if [ $? -ne 0 ] ; then
	exit
fi

ONLINE=`gregkh_machine_online`
# Only push if we have a network connection
if [ "$ONLINE" = "1" ] ; then
	for remote in `git remote`
	do
		git push ${remote} ${TREE}-${BRANCH}
	done
fi

# now go back to the original branch so that we can continue to work
git checkout work-${BRANCH}
