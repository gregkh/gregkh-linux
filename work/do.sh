#!/bin/bash

PWD=`pwd`
TREE=`basename ${PWD}`

git fp ${TREE}-linus &&				\
	../added-to-${TREE} 0*.patch &&		\
	git checkout ${TREE}-linus && 		\
	git merge work &&			\
	git push kroah.com &&			\
	git push &&				\
	git checkout work
