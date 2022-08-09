#!/bin/bash

for VERSION in $(cat active_kernel_versions); do
	echo -n "${VERSION} "
done
echo ""

