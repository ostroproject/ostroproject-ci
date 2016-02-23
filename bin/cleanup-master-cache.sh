#!/bin/bash -eu
#
# cleanup-master-cache.sh: Clean up older files in master CI cache
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
echo "======= delete older files from master cache area ======"
find ${HOME}/${CI_EXPORT}/ -type f -name 'jenkins-*.tar.gz' -mtime +30 -exec rm -v {} \;
find ${HOME}/${CI_EXPORT}/ -type f -name 'env.properties.*' -mtime +30 -exec rm -v {} \;
find ${HOME}/${CI_EXPORT}/ -type f -name '*.testruns.csv.*' -mtime +30 -exec rm -v {} \;

echo "======= delete older testresults from master cache area ======"
# recursively delete directories, -depth avoids deleting in-processing path
find ${HOME}/${CI_TESTRESULTS_CACHE}/ -depth -type d -mtime +30 -exec rm -vfr {} \;
