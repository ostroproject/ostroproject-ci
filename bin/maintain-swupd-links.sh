#!/bin/bash -eu
#
# maintain-swupd-links.sh: keep swupd area links up to date
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
# Maintain swupd-related symlinks from updates/ to builds/
# We add numbered symlinks and update latest link. We do not delete.
# This runs on external download server.

# This script is used both on external DNL server, and internal coordinator.
# BUILD_STORAGE_BASE is defined on nodes properties,
# as all functionality is otherwise same.

if [ ! -v BUILD_STORAGE_BASE ]; then
  echo "This script needs BUILD_STORAGE_BASE to point to builds area"
  exit 1
fi

_buildsroot=${BUILD_STORAGE_BASE}/builds/ostro-os
_updroot=${BUILD_STORAGE_BASE}/updates/ostro-os/builds

_builds=`ls -d ${_buildsroot}/*-build-*`
for _bld in ${_builds}; do
  _machdirs=""
  [ -d ${_bld}/swupd ] && _machdirs=`ls -d ${_bld}/swupd/*`
  if [ -n "${_machdirs}" ]; then
    #echo "  machdirs are $_machdirs"
    for _machdir in ${_machdirs}; do
      _mach=`basename $_machdir`
      _streams=`ls -d ${_machdir}/*`
      #echo "   $_mach streams are $_streams"
      for _strmdir in ${_streams}; do
        _strm=`basename $_strmdir`
        _verdir=`ls -d ${_strmdir}/[0-9]*`
        _version=`basename $_verdir`
        #echo "     $_strm version is $_version"
        # create dirs if no dir tree yet
        mkdir -vp $_updroot/$_mach/$_strm
        # add version link for that machine and stream
        [ ! -h "$_updroot/$_mach/$_strm/$_version" ] && ln -vsf ${_verdir} $_updroot/$_mach/$_strm/$_version
        # copy subtree containing latest link
        cp -av $_buildsroot/latest/swupd/$_mach/$_strm/version $_updroot/$_mach/$_strm/
      done
    done
  fi
done
