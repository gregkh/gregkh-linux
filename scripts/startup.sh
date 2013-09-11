#!/bin/bash


# do at every boot
sudo mount -t tmpfs tmpfs -o size=40G tmp
cd linux/stable/linux-stable
git fetch
~/update_all_branches
#git checkout linux-3.0.y && git pull
#git checkout linux-3.4.y && git pull
##git checkout linux-3.5.y && git pull
##git checkout linux-3.6.y && git pull
#git checkout linux-3.7.y && git pull
#git checkout master && git pull
cd

echo "machine is up and running" | mutt -s "machine is up and running" -- greg@kroah.com
sleep 3
sudo /etc/init.d/sendmail restart

