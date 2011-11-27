#!/bin/bash

PWD=`pwd`
TREE=`basename ${PWD}`

git fp ${TREE}-linus &&				\
	../added-to-${TREE} 0*.patch &&		\
	git checkout ${TREE}-linus && 		\
	git merge work

# if something goes wrong, exit
if [ $? -ne 0 ] ; then
	exit
fi

# Only push if we have a network connection
NM_STATUS=`nmcli -terse -f state nm`
if [ "$NM_STATUS" = "connected" ] ; then
	git push kroah.com && git push
fi

git checkout work
