#!/bin/bash

~/.local/bin/tuxsuite plan \
    --git-repo 'https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git' \
    --git-ref linux-5.16.y \
    --patch-series /home/gregkh/linux/stable/stable-queue/5.16.patches.tar.gz \
    arm32.plan
