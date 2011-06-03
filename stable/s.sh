#!/bin/bash

USER=`whoami`

DIR=/home/$USER/linux/stable
SCRIPT_DIR=/home/$USER/linux
KERNEL_DIR=$DIR/linux-2.6.39.y

cd $DIR
cat - > $DIR/foo.patch
#perl $DIR/x.pl
dos2unix $DIR/foo.patch
$SCRIPT_DIR/fix_patch $DIR/foo.patch
#vim -T xterm $DIR/foo.patch
${VISUAL:-${EDITOR:-vi}} "$DIR/foo.patch" < /dev/tty
file=`rename-patch $DIR/foo.patch`
echo "filename is $file"
cd $KERNEL_DIR
pwd
#quilt import $DIR/$file
quilt import $file
quilt push && quilt ref && quilt pop && quilt push

