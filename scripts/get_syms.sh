#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#
# Build the kernel and detect all files that are actually touched
#
# (C) 2023 Greg Kroah-Hartman <gregkh@linuxfoundation.org>
#

BUILDSNOOP="./buildsnoop.bt"
BUILD_COMMAND="make CC=gcc-11 -j100"
FINAL_LIST="files_touched_in_build"


SCRIPT=${0##*/}

# create some tempfiles to use.
BUILDSNOOP_LIST=$(mktemp "${SCRIPT}".XXXX) || exit 1
GITFILE_LIST=$(mktemp "${SCRIPT}".XXXX) || exit 1
TEMPFILE_LIST=$(mktemp "${SCRIPT}".XXXX) || exit 1

echo "we are going to run ${BUILDSNOOP} as root now, sorry about that"
sudo BPFTRACE_STRLEN=128 ${BUILDSNOOP} > ${BUILDSNOOP_LIST} &

SNOOPID=$!

# now build the kernel
echo "building the kernel with '${BUILD_COMMAND}'"
${BUILD_COMMAND}

# we are done, so kill the opensnoop process
kill ${SNOOPID}

echo "processing the list of files"

# process the list of files by doing some basic text manipulations
#
# - sort the list
# - get only unique names
# - tweak the filenames by dropping the initial './' as some build processes add that
# - do step 5 again, as some build processes add yet-another one
# - sort list again
# - get only unique files again

sort "${BUILDSNOOP_LIST}" | uniq | sed 's/^\.\///' | sed 's/^\.\///' | sort | uniq > "${TEMPFILE_LIST}"

# now walk the list and convert all using 'realpath' to normalize some crazy ..' stuff
realpath --relative-to=. tools/include/../include/linux/objtool.h


# Now let's cheat, and get a full list of everything that git thinks is a valid
# file in its repo, and then just compare the two lists and take the files that
# match

git ls-files | sort > "${GITFILE_LIST}"
comm -1 -2 "${GITFILE_LIST}" "${TEMPFILE_LIST}" > "${FINAL_LIST}"

# count the number of files and the lines as that's fun to know

TOTAL_LINES=0
while read -r FILE ; do
	LINES=$(wc -l "${FILE}" | cut -f 1 -d ' ')
	TOTAL_LINES=$((LINES + TOTAL_LINES))
done < "${FINAL_LIST}"

TOTAL_FILES=$(wc -l ${FINAL_LIST} | cut -f 1 -d ' ')

printf "\n  Total: %9d files\t%9d lines\n\n" ${TOTAL_FILES} ${TOTAL_LINES}

# look at all filenames and run some simple "is this really a file we care
# about" type tests
#while read -r filename
#do
#	if [[ -d "${filename}" ]]; then
#		continue
#	fi
#
#	echo "${filename}" >> foo.4
#done < foo.3

echo "Full list of files is in ${FINAL_LIST}"


rm "${BUILDSNOOP_LIST}"
rm "${GITFILE_LIST}"
rm "${TEMPFILE_LIST}"


