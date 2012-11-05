#!/bin/bash
#
# Copyright 2012 Greg Kroah-Hartman <greg@kroah.com>
# Copyright 2012 Linux Foundation
#
# Released under the GPLv2 only.
#
# Initialize the linux repo with the remote git trees that I need in order to
# get things done.  This consists of the development trees in the work/
# directory, my local gregkh/ directory and patch queue, and the stable trees.
#
# The work directory is the most complex, it consists of one "root" repo,
# called "torvalds" that is based on Linus's upstream kernel tree.  I then
# create multiple trees based on that, each in a separate subdirectory, based
# on the "topic".  In each of those trees, I have a 'next' and 'linus' branch
# that is used to send stuff to linux-next and Linus's tree, respectively.
#
# I also do the "work" on branches that are based on these 'next' and 'linus'
# branches, that is what the 'send the email' scripts expect patches to be
# applied to, so they know how to push and notify people when stuff is added.
#
# The main gregkh/ directory is what I do local work on for things not ready to
# be merged upstream.  It's also tied to a quilt tree, to save patches in a
# safe place for storage and passing to other machines.
# Yeah, it's a bit complex, but it works for me.
#

# go into the work directory and set up everything there first.

cd work/

WORK_TREES="driver-core staging tty usb char-misc"

# First, clone Linus's tree in --bare mode as we are going to work off of that:
git clone --bare git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git torvalds

# for local testing, to make it faster...
#git clone --bare gregkh@clark:linux/work/torvalds torvalds

# now make clones of it for the different work types
for TREE in ${WORK_TREES}
do
	echo "*** creating ${TREE} tree"
	git clone -s torvalds ${TREE}

	echo "*** setting up the master link"
	cd ${TREE}
	git remote add temp gitolite@198.145.19.202:/pub/scm/linux/kernel/git/gregkh/${TREE}.git
	git remote rm origin
	git remote rename temp origin

	# ok, there has to be a better way than to add the following lines to
	# the git config to have the master branch track the remote master
	# branch, but I can't figure it out...
	echo "[branch \"master\"]"		>> .git/config
	echo "	remote = origin"		>> .git/config
	echo "	merge = refs/heads/master"	>> .git/config

	echo "*** setting up kroah.com link"
	git remote add kroah.com git@git.kroah.com:kernel/${TREE}.git

	echo "*** fetching from remote repo"
	git fetch origin

	echo "*** setting up branches"
	git checkout -t -b ${TREE}-linus origin/${TREE}-linus
	git checkout -b work-linus ${TREE}-linus
	git checkout -t -b ${TREE}-next origin/${TREE}-next
	git checkout -b work-next ${TREE}-next


	cd ..
done

# make empty files for patch work
touch s s1 s2


cd ..

# clone my local tree, so that I can do stuff
echo "*** Creating gregkh repo"
git clone --shared work/torvalds gregkh

# clone my patch queue, not much there, but it's a place to work from
echo "*** Cloning patch queue"
git clone gitolite@ra.kernel.org:/pub/scm/linux/kernel/git/gregkh/patches.git patches
cd patches
git remote add kroah.com git@git.kroah.com:kernel/patches.git
cd ..

# Now for the stable stuff
echo "*** Setting up the Stable directories"
cd stable/

# we need the stable-queue first
echo "*** Cloning the stable-queue"
git clone gitolite@ra.kernel.org:/pub/scm/linux/kernel/git/stable/stable-queue.git
cd stable-queue
git remote add kroah.com git@git.kroah.com:kernel/stable-queue.git
cd ..

echo "*** Cloning the linux-stable tree, will take a while"
git clone gitolite@ra.kernel.org:/pub/scm/linux/kernel/git/stable/linux-stable.git
echo "*** Done, please set up the branches and stable repos as you need."

cd ..

echo "*** Also set up longterm/ if you still need it."

