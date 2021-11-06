#!/usr/bin/env python3
#
# extract the initial "Link" for a stable -rc announcement and all of the
# Tested-by lines to be added to the git commit for the release.
#

from argparse import ArgumentParser
import mailbox
import sys

parser = ArgumentParser(description='mbox to tested-by list')
parser.add_argument('inbox', metavar='inbox')

args = parser.parse_args()

mbox = mailbox.mbox(args.inbox, create=False)

for k, msg in mbox.items():
    id=msg.get('Message-ID')
    sys.stdout.write('message id %s\n' %msg.get('Message-ID'))


exit

'''

mbox=${1}

if [ "${mbox}" == "" ] ; then
	echo "$0 mbox"
	exit 1
fi

messageid=$(grep -i --max-count=1 "^Message-id:" "${mbox}" | cut -f 2 -d '<' | cut -f 1 -d '>')
#echo "Link: https://lore.kernel.org/r/${messageid}"
out="Link: https://lore.kernel.org/r/${messageid}
"

out+=$(grep -i '^Tested-by:\|^Reviewed-by:' ${mbox})

printf '%s\n' "${out}"

echo "${out}" | xclip -selection c
'''
