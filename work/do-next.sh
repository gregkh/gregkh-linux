#!/bin/bash

PWD=`pwd`
TREE=`basename ${PWD}`

#git fp tty-next && ../added-to-tty-next 0*.patch && git checkout tty-next && git merge work && git push && git checkout work
git fp ${TREE}-next &&				\
	../added-to-${TREE}-next 0*.patch &&	\
	git checkout ${TREE}-next && 		\
	git merge work &&			\
	git push kroah.com &&			\
	git push &&				\
	git checkout work
