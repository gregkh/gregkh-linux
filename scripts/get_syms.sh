#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#
# Build the kernel and detect all files that are actually touched
#
# (C) 2023 Greg Kroah-Hartman <gregkh@linuxfoundation.org>
#

BUILD_COMMAND="make CC=gcc-11 -j100"
FINAL_LIST="files_touched_in_build"


SCRIPT=${0##*/}

# check for sudo permission before we try to do much of anything
sudo -v || exit 1

# create some tempfiles to use.
BUILDSNOOP_LIST=$(mktemp "${SCRIPT}".XXXX) || exit 1
BUILDSNOOP_BT=$(mktemp "${SCRIPT}".XXXX.bt) || exit 1
GITFILE_LIST=$(mktemp "${SCRIPT}".XXXX) || exit 1
TEMPFILE_LIST=$(mktemp "${SCRIPT}".XXXX) || exit 1
TEMPFILE2_LIST=$(mktemp "${SCRIPT}".XXXX) || exit 1


cat << __EOF__ > "${BUILDSNOOP_BT}"
#!/usr/bin/env bpftrace
// SPDX-License-Identifier: Apache-2.0
/*
 * snoop and print out the filename of anything opened
 *
 * Based on opensnoop.bt from Brendan Gregg, but stripped
 * down to almost nothing
 */
tracepoint:syscalls:sys_enter_open,
tracepoint:syscalls:sys_enter_openat
{
	printf("%s\n", str(args->filename));
}
__EOF__

chmod 755 "${BUILDSNOOP_BT}"

echo "we are going to run ${BUILDSNOOP_BT} as root now, sorry about that"
sudo BPFTRACE_STRLEN=128 ./"${BUILDSNOOP_BT}" > "${BUILDSNOOP_LIST}" &

SNOOPID=$!

# now build the kernel
echo "building the kernel with '${BUILD_COMMAND}'"
${BUILD_COMMAND}

# we are done, so kill the opensnoop process
kill ${SNOOPID}
rm "${BUILDSNOOP_BT}"

echo "Processing the list of files"
echo "  - sorting..."

# process the list of files by doing some basic text manipulations
#
# - sort the list
# - get only unique names
# - tweak the filenames by dropping the initial './' as some build processes add that
# - do step 5 again, as some build processes add yet-another one
# - sort list again
# - get only unique files again

sort "${BUILDSNOOP_LIST}" | uniq | sed 's/^\.\///' | sed 's/^\.\///' | sort | uniq > "${TEMPFILE_LIST}"

#  Walk the list and convert all using 'realpath' to normalize some crazy ..' stuff
REAL_COUNT=$(wc -l ${TEMPFILE_LIST} | cut -f 1 -d ' ')
echo "  - resolving ${REAL_COUNT} filenames..."
while read -r FILE ; do
	REAL_FILE=$(realpath --relative-to=. "${FILE}" 2>/dev/null)
	if [[ "${REAL_FILE}" != "" ]] ; then
		echo "${REAL_FILE}" >> "${TEMPFILE2_LIST}"
	fi
done < "${TEMPFILE_LIST}"
sort "${TEMPFILE2_LIST}" | uniq > "${TEMPFILE_LIST}"

# Now let's cheat, and get a full list of everything that git thinks is a valid
# file in its repo, and then just compare the two lists and take the files that
# match
echo "  - using git to figure stuff out..."
git ls-files | sort > "${GITFILE_LIST}"
comm -1 -2 "${GITFILE_LIST}" "${TEMPFILE_LIST}" > "${FINAL_LIST}"

# count the number of files and the lines as that's fun to know
echo "  - counting lines"
TOTAL_LINES=0
C_LINE_COUNT=0
C_FILE_COUNT=0
H_LINE_COUNT=0
H_FILE_COUNT=0
R_LINE_COUNT=0
R_FILE_COUNT=0

while read -r FILE ; do
	LINES=$(wc -l "${FILE}" | cut -f 1 -d ' ')
	SUFFIX=${FILE:(-2)}
	if [[ "${SUFFIX}" == ".c" ]] ; then
		C_LINE_COUNT=$((LINES + C_LINE_COUNT))
		C_FILE_COUNT=$((1 + C_FILE_COUNT))
	elif [[ "${SUFFIX}" == ".h" ]] ; then
		H_LINE_COUNT=$((LINES + H_LINE_COUNT))
		H_FILE_COUNT=$((1 + H_FILE_COUNT))
	else
		R_LINE_COUNT=$((LINES + R_LINE_COUNT))
		R_FILE_COUNT=$((1 + R_FILE_COUNT))
	fi

	TOTAL_LINES=$((LINES + TOTAL_LINES))
	TOTAL_FILES=$((1 + TOTAL_FILES))
done < "${FINAL_LIST}"

#TOTAL_FILES=$(wc -l ${FINAL_LIST} | cut -f 1 -d ' ')

printf "     .c: %9d files\t%9d lines\n" "${C_FILE_COUNT}" "${C_LINE_COUNT}"
printf "     .h: %9d files\t%9d lines\n" "${H_FILE_COUNT}" "${H_LINE_COUNT}"
printf "  other: %9d files\t%9d lines\n" "${R_FILE_COUNT}" "${R_LINE_COUNT}"
printf "  Total: %9d files\t%9d lines\n" "${TOTAL_FILES}" "${TOTAL_LINES}"

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
rm "${TEMPFILE2_LIST}"

