#!/bin/sh -xeu
#
# build-publish-sources.sh: publish sources cache to external dnl site.
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

#
# This runs on a worker
#

# copy new sources cache contents
_SRC=${BB_CACHE_BASE}/sources
_DEST=rsync://localhost:8873/content_RW_ostro/mirror

rsync -avzE --exclude=images/edison/.nfs* --exclude=*.lock ${_SRC} ${_DEST}/
