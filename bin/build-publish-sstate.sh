#!/bin/sh -xeu
#
# build-publish-sstate.sh: publish sstate to external dnl site.
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

# copy new sstate contents
_SRC=${BB_CACHE_BASE}/sstate
_DEST=rsync://localhost:8873/content_RW_ostro/sstate/${CI_PUBLISH_NAME}

rsync -avzE ${_SRC}/* ${_DEST}/
