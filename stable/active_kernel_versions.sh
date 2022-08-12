#!/bin/bash

for VERSION in $(cat /home/gregkh/linux/stable/active_kernel_versions); do
	echo -n "${VERSION} "
done
echo ""

