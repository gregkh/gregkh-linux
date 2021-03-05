#!/bin/bash

~/.local/bin/tuxsuite build-set \
    --git-repo 'https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable-rc.git' \
    --git-ref queue/5.11 \
    --tux-config x86.yaml \
    --set-name x86
