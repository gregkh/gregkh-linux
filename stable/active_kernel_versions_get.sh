#!/bin/bash

VERSIONS=$(/home/gregkh/linux/stable/active_kernel_versions.sh)
V=$(gum choose --no-limit ${VERSIONS})
echo "${V}"
exit
