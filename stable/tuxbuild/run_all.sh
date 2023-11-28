#!/bin/bash

~/.local/bin/tuxsuite plan \
    --git-repo 'https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable-rc.git' \
    --git-ref queue/5.15 \
    all.yaml
