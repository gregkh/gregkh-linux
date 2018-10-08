#!/bin/bash
#
# take a kernel version, git tree, and tag/branch and turn them into a
# mbox of patches to be applied to the stable tree
#
# run this in a linux-stable tree:
# $0 KERNEL_VERSION GIT_URL TAG


VERSION=$1
URL=$2
TAG=$3

if [ "${TAG}" == "" ] ; then
	echo "$0 VERSION GIT_URL TAG/BRANCH"
	exit
fi

BRANCH="linux-${VERSION}.y"

git branch -D s-${VERSION}
git co -b s-${VERSION} linux-${VERSION}.y

git pull ${URL} ${TAG}

git rebase linux-${VERSION}.y

git fp linux-${VERSION}.y

cat *patch > mbox.${VERSION}


