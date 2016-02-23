#!/bin/sh -eu
#
# maintain-swupd-pr-cross-links.sh: create,delete PR project swupd links
# Copyright (c) 2016, Intel Corporation.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms and conditions of the GNU General Public License,
# version 2, as published by the Free Software Foundation.
#
# This program is distributed in the hope it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# Create Ostro CI swupd cross-build symlinks:
# - a PR build gets links to all older builds of same PR
# - a PR build gets links to all master builds
# - delete such links to builds that have gone away via cleanup
#
# This runs on coordinator
#

create_links()
{
  _to=$1
  _from=$2
  # create link only if "to" directory exists
  if [ -d $_to ]; then
    # have to use find instead of ls to leave out links created by same script.
    # we need to react only on directories
    verdir=`find $_to/ -maxdepth 1 -type d -name [0-9]*`
    ver=`basename $verdir`
    # create only if there is no link yet
    if [ ! -L $_from/$ver ]; then
      ln -vsr $_to/$ver $_from/
    fi
  fi
}

remove_old_links()
{
  _dir=$1
  # remove symlinks pointing to dirs that have gone away
  # we can use ls instead of find, as "! -d" match below can only
  # be true for links where target has been removed
  _links=`ls -d $_dir/[0-9]*`
  for link in $_links; do
    if [ ! -d $_link ]; then
      rm -v $_link
    fi
  done
}

pr_dirs=`ls -d ${STORE_BASE}/builds/*_pull-requests`
master_dirs=`find ${STORE_BASE}/builds/${DISTRO_NAME}/ -mindepth 1 -maxdepth 1 -type d`

# walk tree: pr_dir - swupd - machine - stream
for dir in $pr_dirs; do
  older_same_pr_dirs=""
  ###echo dir=$dir
  swupd_dirs=`find $dir -maxdepth 3 -type d -name swupd |sort`
  for swdir in $swupd_dirs; do
    ###echo "  swupd_dir=$swdir"
    machine_dirs=`ls -d ${swdir}/*`
    for machdir in $machine_dirs; do
      mach=`basename $machdir`
      ###echo "    mach_dir=$machdir"
      stream_dirs=`ls -d ${machdir}/*`
      for strmdir in $stream_dirs; do
        strm=`basename $strmdir`
        ###echo "      strm_dir=$strmdir"
        remove_old_links $strmdir
        for older_dir in $older_same_pr_dirs; do
          # create symlinks pointing to all previous swupd dirs of same PR
          create_links $older_dir/$mach/$strm $strmdir
        done
        for master_dir in $master_dirs; do
          # create symlinks pointing to all master build swupd dirs
          create_links $master_dir/swupd/$mach/$strm $strmdir
        done
      done
    done
    # add dir we just processed, to older_dir list, building up previous PR dirs list
    older_same_pr_dirs="$older_same_pr_dirs $swdir"
  done
done
