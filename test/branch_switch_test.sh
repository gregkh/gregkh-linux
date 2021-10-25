#!/bin/bash
cd test
git co -b old_kernel v4.4
sync
git co -b new_kernel v5.8
sync
