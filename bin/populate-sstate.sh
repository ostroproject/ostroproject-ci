#!/bin/bash -u
#
# populate-sstate.sh: populate newly created sstate files into master cache
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
# This should run on a worker.
# We dont want to populate files from sstate main level as these are
# fetched from mirror. Skip is achieved with min/max depth options.
# In subdirs we dont want symlinks, achieved by rsync skipping symlinks
# with given options.
#
if [ -v CI_POPULATE_SSTATE ]; then
  _src=${BB_CACHE_BASE}/${PARENT_JOB_NAME}/sstate.${CI_BUILD_ID}
  _dst=${BB_CACHE_BASE}/sstate
  find ${_src} -mindepth 1 -maxdepth 1 -type d -exec rsync -vrptgE {} ${_dst}/ \;
fi
