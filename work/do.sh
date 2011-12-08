#!/bin/bash
#
# Take the branch we are working on, create the patches, email out that we
# applied them, merge to the branch, and push the branch to the servers if we
# are online.

# determine if we are online or not, depending on the machine
online()
{
	ONLINE=0

	# some machines I don't use network manager, so handle them
	HOSTNAME=`hostname -s`
	if [ "$HOSTNAME" = "clark" ] ; then
		ONLINE=1
	fi

	# check network manager to see if we are online
	NM_STATUS=`nmcli -terse -f state nm`
	if [ "$NM_STATUS" = "connected" ] ; then
		ONLINE=1
	fi
}


# we need to be either on the 'work-next' branch, or the 'work-linus' branch in
# order to work properly, error out if we are on something else.
CURRENT_BRANCH=`git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/'`
BRANCH=""
if [ "$CURRENT_BRANCH" = "work-next" ] ; then
	BRANCH="next"
else if [ "$CURRENT_BRANCH" = "work-linus" ] ; then
	BRANCH="linus"
fi
fi

if [ "$BRANCH" = "" ] ; then
	echo "ERROR!!!"
	echo "Right now you are on the \"$CURRENT_BRANCH\" branch."
	echo "You need to be on either \"work-next\" or \"work-linus\" branch to work properly."
	exit
fi
echo "BRANCH=$BRANCH"

# look and see if there are any patches in this dir first, error out if so, we
# don't want to accidentally send them out twice
OLD_PATCH=`ls 0*.patch 2>/dev/null | head -n 1`
if [ "${OLD_PATCH}" != "" ] ; then
	echo "ERROR!!!"
	echo "There are old patches still in the directory,"
	echo "clean them up before running this again."
	exit
fi

PWD=`pwd`
TREE=`basename ${PWD}`

# generate the patches
# 'fp' is my alias for 'format-patch -k -M -N'
git fp ${TREE}-${BRANCH}

# verify that we actually generated some patches
PATCH=`ls 0*.patch 2>/dev/null | head -n 1`
if [ "${PATCH}" = "" ] ; then
	echo "ERROR!!!"
	echo "No patches were generated, are you sure you actually committed anything here?"
	exit
fi

# send out emails
../added-to-${TREE}-${BRANCH} 0*.patch

# merge the patches back to the branch
git checkout ${TREE}-${BRANCH} && git merge work-${BRANCH}

# if something goes wrong, exit
if [ $? -ne 0 ] ; then
	exit
fi

online
# Only push if we have a network connection
if [ "$ONLINE" = "1" ] ; then
	git push kroah.com && git push
fi

# now go back to the original branch so that we can continue to work
git checkout work-${BRANCH}
