#!/bin/sh -xue
#
# build-post.sh: called as post-build step from building jobs
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
# This is called regardless of build steps sttaus, so here is correct place
# for stop and cleanup that should happen regardless of buils steps status.

${WORKSPACE}/ci/bin/pr_serv_stop.sh
