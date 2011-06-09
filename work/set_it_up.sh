#!/bin/bash

TREES="driver-core staging tty usb"

# First, clone Linus's tree in --bare mode as we are going to work off of that:
#git clone --bare gregkh@master.kernel.org:/pub/scm/linux/kernel/git/torvalds/linux-2.6.git torvalds

# now make clones of it for the different work types
for TREE in $TREES
do
	echo "*** creating $TREE tree"
	git clone torvalds $TREE

	echo "*** setting up the master link"
	cd $TREE
	git remote add temp gregkh@master.kernel.org:/pub/scm/linux/kernel/git/gregkh/${TREE}-2.6.git
	git remote rm origin
	git remote rename temp origin

	echo "*** fetching from remote repo"
	git fetch

	echo "*** setting up branches"
	git checkout -t -b $TREE-next origin/$TREE-next
	git checkout -t -b $TREE-linus origin/$TREE-linus

	cd ..
done

# make empty files for patch work
touch s s1 s2

