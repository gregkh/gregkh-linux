#!/bin/bash

~/.local/bin/tuxsuite build-set \
    --git-repo 'https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable-rc.git' \
    --git-ref queue/4.14 \
    --tux-config one_s390.yaml \
    --set-name one_s390
