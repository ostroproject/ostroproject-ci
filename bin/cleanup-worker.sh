#!/bin/bash -u
#
# cleanup-worker.sh: Clean up old sstate elems, runs on worker
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
echo "=== delete older sstate instances ==="
_opts="-mindepth 1 -maxdepth 1 -type d"
_age="-mtime +14"
_elems="master pull-requests"
for _area in ${_elems}; do
  _path=${BB_CACHE_BASE}/${DISTRO_NAME}_${_area}
  if [ -d ${_path} ]; then
    echo "=== delete under ${_path} ==="
    find ${_path} ${_opts} ${_age} -print -exec rm -fr {} \;
  fi
done
