#!/bin/sh -xeu
#
# build-prepare.sh: preparation for build on coordinator.
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
# Common script before jobs, runs on coordinator, prepares for build:
# - creates directory DEST and directories under it
# - stores tar ball and env.properties in worker-cache
#   (both are received from CI master at start of this job)
# - calls PR start script

_DEST=${PUBLISH_DIR}/${CI_BUILD_ID}
# create toplevel publish directory and subdirs under it
mkdir -p ${_DEST}
for d in ${PUBLISH_SUBDIRS}; do
  mkdir ${_DEST}/${d}
done
# create MACHINE subdirs under some publish subdirs
for d in ${PUBLISH_SUBDIRS_W_MACHINES}; do
  for m in ${MACHINES}; do
    mkdir ${_DEST}/${d}/${m}
  done
done

# store tarball to workers cache
mv ${CI_EXPORT}/${CI_TARBALL} ${STORE_BASE}/${CI_WORKERS_CACHE}/
# store env.properties to workers cache
mv ${CI_EXPORT}/env.properties.${CI_BUILD_ID} ${STORE_BASE}/${CI_WORKERS_CACHE}/

# Start PR server
${WORKSPACE}/ci/bin/pr_serv_start.sh
