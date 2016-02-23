#!/bin/bash -xeu
#
# build-recipe-selftests.sh: run recipes checking pass before building.
#
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
# This runs on a builder worker

PATH=$PATH:/usr/sbin
env | sort

rm -fr ${DISTRO_NAME}
mkdir -p ${DISTRO_NAME}
cd ${DISTRO_NAME}

# get source tarball that master prepared for this build job
if [ -f ${STORE_BASE}/${CI_WORKERS_CACHE}/${CI_TARBALL} ]; then
  # new CI: workers have cache area nfs-mounted
  tar xfz ${STORE_BASE}/${CI_WORKERS_CACHE}/${CI_TARBALL}
else
  # old CI: get tarball from coordinator over rsync
  rsync -av rsync://${COORD_ADDR}/${CI_WORKERS_CACHE}/${CI_TARBALL} .
  tar xfz ${CI_TARBALL}
  rm -f ${CI_TARBALL}
fi

# ########################################
# Initialize build configuration variables
#
_BUILDDIR="build"

set +u
# Initialize bitbake
. ./oe-init-build-env "$_BUILDDIR"

# add special development-mode image setting
cat >> "${WORKSPACE}/${DISTRO_NAME}/build/conf/auto.conf" << EOF
include conf/distro/include/ostro-os-development.inc
EOF

oe-selftest --run-tests iotsstatetests.SStateTests.test_sstate_samesigs
