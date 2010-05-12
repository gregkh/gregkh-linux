#!/bin/bash

DIR=~/linux
KERNEL_DIR=$DIR/gregkh-2.6

cd $DIR
cat - > $DIR/foo.patch
#perl $DIR/x.pl
$DIR/fix_patch $DIR/foo.patch
dos2unix $DIR/foo.patch

#perl $DIR/mime_decode -f $DIR/foo.patch

#vim -T xterm $DIR/foo.patch
${VISUAL:-${EDITOR:-vi}} "$DIR/foo.patch" < /dev/tty
file=`rename-patch $DIR/foo.patch`
echo "filename is $file"
cd $KERNEL_DIR
#quilt import $DIR/$file
quilt import $file
quilt push && quilt ref && quilt pop && quilt push

