#!/bin/sh -xeu
#
# build-metalayer.sh: First script of metalayer head, or PR build
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

env | sort
# This is toplevel job starting point. Remove previous env.properties
# for case of failure before creating current one, to avoid old ctxt use
# by post-build steps which run regardless of step failures
rm -f env.properties
${HOME}/ci/bin/combine-layers.sh ${CI_PUBLISH_NAME}
${HOME}/ci/bin/build-prepare-master.sh ${CI_COMBO_DIR}/${DISTRO_NAME}
