#!/bin/bash
#
# Take the branch we are working on, create the patches, email out that we
# applied them, merge to the branch, and push the branch to the servers if we
# are online.


PWD=`pwd`
TREE=`basename ${PWD}`

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



#git fp tty-next && ../added-to-tty-next 0*.patch && git checkout tty-next && git merge work && git push && git checkout work
git fp ${TREE}-next &&				\
	../added-to-${TREE}-next 0*.patch &&	\
	git checkout ${TREE}-next && 		\
	git merge work

# if something goes wrong, exit
if [ $? -ne 0 ] ; then
	exit
fi

online

# Only push if we have a network connection
if [ "$ONLINE" = "1" ] ; then
	git push kroah.com && git push
fi

git checkout work
