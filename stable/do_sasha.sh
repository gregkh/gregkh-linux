#!/bin/bash

VERSION="4.18"

URL=$1
TAG=$2

if [ "${TAG}" == "" ] ; then
	echo "$0 URL TAG"
	exit
fi

BRANCH="linux-${VERSION}.y"

git branch -D s-${VERSION}
git co -b s-${VERSION} linux-${VERSION}.y

git pull ${URL} ${TAG}

git rebase linux-${VERSION}.y

git fp linux-${VERSION}.y

cat *patch > mbox.${VERSION}


