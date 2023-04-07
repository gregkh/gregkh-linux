#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#
# Build the kernel and detect all files that are actually touched
#
# (C) 2023 Greg Kroah-Hartman <gregkh@linuxfoundation.org>
#

SCRIPT=${0##*/}

# options that can be overwritten by the command line
OPTION_MAKE="make -j20"		# build/make command
OPTION_FILE_LIST=""		# filename of final list of files, if wanted
OPTION_COUNT=0			# do we do a line/file count?
OPTION_KERNEL_DIR="."		# where the kernel directory really is
OPTION_TMPDIR=${TMPDIR:-/tmp}	# tmpdir

function help {
	cat << __EOF__ >&2
USAGE: ${SCRIPT} [options]

Built a Linux kernel and calculate some staticics and save off the list of
files that made up the build.

Note, requires the bpftrace tool to be installed on the system.

Availble options:
 --make="build command"		-- command to use to build the kernel default
				   is "make -j20"
 --kernel_dir="directory"	-- if the kernel source directory is not in the
				   current directory, it can be specified here.
 --file_list="filename"		-- if specified the list of files touched will
				   be saved to the specified file
 --tmpdir="tempdir"		-- if specified, the temporary directory to
				   use, otherwise TMPDIR from the environment
				   is used.
 --count			-- if specified, the line and file counts of
				   the files touched in the build will be
				   outputed to standard output.
 --help				-- this help text.
__EOF__
	exit
}

# Parse all arguments
options=$(getopt -o h --long make:,kernel_dir:,file_list:,tmpdir:,count,help -- "$@")
if [[ $? -ne 0 ]] ; then
	help
fi
eval set -- "$options"
while true
do
	case "$1" in
	-h)
		help ;;
	--help)
		help ;;
	--make)
		OPTION_MAKE="$2"
		shift 2 ;;
	--kernel_dir)
		OPTION_KERNEL_DIR="$2"
		shift 2 ;;
	--file_list)
		OPTION_FILE_LIST="$2"
		shift 2 ;;
	--tmpdir)
		OPTION_TMPDIR="$2"
		shift 2 ;;
	--count)
		OPTION_COUNT=1
		shift ;;
	--)
		shift
		break ;;
	esac
done

# verify that bpftrace is on the system
BPFTRACE=$(which bpftrace 2> /dev/null)
if [[ "${BPFTRACE}" == "" ]] ; then
	echo "bpftrace is required to be able to trace the kernel build."
	echo "Please install in order to use this tool properly."
	exit 1
fi

# check for sudo permission before we try to do much of anything
sudo -v || exit 1

# debugging stuff to comment out if things are going odd.
#echo "OPTION_MAKE=\"${OPTION_MAKE}\""
#echo "OPTION_FILE_LIST=\"${OPTION_FILE_LIST}\""
#echo "OPTION_COUNT=\"${OPTION_COUNT}\""
#echo "OPTION_KERNEL_DIR=\"${OPTION_KERNEL_DIR}\""
#echo "OPTION_TMPDIR=\"${OPTION_TMPDIR}\""


# create some tempfiles to use.
BUILDSNOOP_LIST=$(mktemp "${OPTION_TMPDIR}/${SCRIPT}".XXXX) || exit 1
BUILDSNOOP_BT=$(mktemp "${OPTION_TMPDIR}/${SCRIPT}".XXXX.bt) || exit 1
GITFILE_LIST=$(mktemp "${OPTION_TMPDIR}/${SCRIPT}".XXXX) || exit 1
TEMP1=$(mktemp "${OPTION_TMPDIR}/${SCRIPT}".XXXX) || exit 1
TEMP2=$(mktemp "${OPTION_TMPDIR}/${SCRIPT}".XXXX) || exit 1
TEMP3=$(mktemp "${OPTION_TMPDIR}/${SCRIPT}".XXXX) || exit 1


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
	\$g = "magic_command_to_exit_trace";
	\$s = str(args->filename);
	printf("%s\n", \$s);
	if (\$s == \$g) {
		exit();
	}
}
__EOF__

echo "Loading the bpftrace script ${BUILDSNOOP_BT} as root now, sorry about that"
sudo BPFTRACE_STRLEN=128 "${BPFTRACE}" "${BUILDSNOOP_BT}" > "${BUILDSNOOP_LIST}" &
SNOOPID=$!

# sleep to get the bpftrace installed...
sleep 5

# now build the kernel
echo "building the kernel with '${OPTION_MAKE}'"
${OPTION_MAKE}

# we are done, so kill the opensnoop process
echo "shutting down the bpftrace script pid: ${SNOOPID}"
cat "magic_command_to_exit_trace" 2>/dev/null
#pids=$(ps ax | grep ${BUILDSNOOP_BT} | awk '{print $1}')
#sudo -v || exit 1
#for pid in ${pids} ; do
#	echo "killing pid ${pid}"
#	sudo kill -9 ${pid} 2>/dev/null
#done
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

sort "${BUILDSNOOP_LIST}" | uniq | sed 's/^\.\///' | sed 's/^\.\///' | sort | uniq > "${TEMP1}"

#  Walk the list and convert all using 'realpath' to normalize some crazy ..' stuff
REAL_COUNT=$(wc -l "${TEMP1}" | cut -f 1 -d ' ')
I=0
while read -r FILE ; do
	REAL_FILE=$(realpath --relative-to="${OPTION_KERNEL_DIR}" "${FILE}" 2>/dev/null)
	if [[ "${REAL_FILE}" != "" ]] ; then
		echo "${REAL_FILE}" >> "${TEMP2}"
	fi
	# Print out the % done every 100 iterations of the loop.
	if [[ "$((I%100))" == "0" ]] ; then
		percent=$((($I*100/$REAL_COUNT*100)/100))
		printf "\r  - resolving ${REAL_COUNT} filenames... ${percent}%%"
	fi
	I=$((I+1))
done < "${TEMP1}"
printf "\r  - resolving ${REAL_COUNT} filenames... 100%%\n"

sort "${TEMP2}" | uniq > "${TEMP1}"
echo "  - resolve list contains $(wc -l "${TEMP1}" | cut -f 1 -d ' ') files"

# Now let's cheat, and get a full list of everything that git thinks is a valid
# file in its repo, and then just compare the two lists and take the files that
# match
echo "  - using git to figure stuff out..."
ORIGINAL_DIR=$(pwd)
cd "${OPTION_KERNEL_DIR}" || exit 1
git ls-files | sort > "${GITFILE_LIST}"
comm -1 -2 "${GITFILE_LIST}" "${TEMP1}" > "${TEMP3}"

# count the number of files and the lines as that's fun to know
if [[ "${OPTION_COUNT}" == "1" ]] ; then
	echo "  - counting lines"
	TOTAL_LINES=0
	C_LINE_COUNT=0
	C_FILE_COUNT=0
	S_LINE_COUNT=0
	S_FILE_COUNT=0
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
		elif [[ "${SUFFIX}" == ".S" ]] ; then
			S_LINE_COUNT=$((LINES + C_LINE_COUNT))
			S_FILE_COUNT=$((1 + C_FILE_COUNT))
		elif [[ "${SUFFIX}" == ".h" ]] ; then
			H_LINE_COUNT=$((LINES + H_LINE_COUNT))
			H_FILE_COUNT=$((1 + H_FILE_COUNT))
		else
			R_LINE_COUNT=$((LINES + R_LINE_COUNT))
			R_FILE_COUNT=$((1 + R_FILE_COUNT))
		fi

		TOTAL_LINES=$((LINES + TOTAL_LINES))
		TOTAL_FILES=$((1 + TOTAL_FILES))
	done < "${TEMP3}"

	printf "     .c: %9d files\t%9d lines\n" "${C_FILE_COUNT}" "${C_LINE_COUNT}"
	printf "     .S: %9d files\t%9d lines\n" "${S_FILE_COUNT}" "${S_LINE_COUNT}"
	printf "     .h: %9d files\t%9d lines\n" "${H_FILE_COUNT}" "${H_LINE_COUNT}"
	printf "  other: %9d files\t%9d lines\n" "${R_FILE_COUNT}" "${R_LINE_COUNT}"
	printf "  Total: %9d files\t%9d lines\n" "${TOTAL_FILES}" "${TOTAL_LINES}"
fi

cd "${ORIGINAL_DIR}" || exit 1

# if asked to save off the file list, do so
if [[ "${OPTION_FILE_LIST}" != "" ]] ; then
	cp "${TEMP3}" "${OPTION_FILE_LIST}"
	echo "Full list of files is now in \"${OPTION_FILE_LIST}\""
fi

# clean up our temp files.
rm "${BUILDSNOOP_LIST}"
rm "${GITFILE_LIST}"
rm "${TEMP1}"
rm "${TEMP2}"
rm "${TEMP3}"

exit
