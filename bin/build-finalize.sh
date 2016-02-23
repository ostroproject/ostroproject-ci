#!/bin/bash -xeu
#
# build-finalize.sh: Finalize the build as build step.
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
# This is called from end of mainlevel build jobs, finalizes build:
#   - creates "latest" symlink
#   - runs hardlink on build area, to reduce space taken
# As after that there will be publish step, we run this sync.mode
# so that publisher gets hardlinked state to transfer

_DEST=${PUBLISH_DIR}/${CI_BUILD_ID}
# ########################################
# Create latest symlink
#
rm -f ${PUBLISH_DIR}/latest
ln -v -s ${CI_BUILD_ID} ${PUBLISH_DIR}/latest
# create file "version" with info needed for swupd server
echo "${CI_BUILD_ID}" > ${PUBLISH_DIR}/latest/version

# ########################################
# Create tarball of sources, if asked. Master build gets this
# Tarball is written directly to build publish area in this host.
#
if [ -v CI_CREATE_GIT_ARCHIVE ]; then
  _ARCHIVENAME=${DISTRO_NAME}_${CI_BUILD_ID}
  rm -fr ${DISTRO_NAME}
  mkdir -p ${DISTRO_NAME}
  cd ${DISTRO_NAME}
  tar xfz ${STORE_BASE}/${CI_WORKERS_CACHE}/${CI_TARBALL}
  git archive --prefix=${_ARCHIVENAME}/ HEAD -o ${_DEST}/${_ARCHIVENAME}.tar.gz
fi

# ########################################
# hardlink build area, as there are big identical files in sdk area
#
# new CI: this runs on coordinator, but builds are stored on storage server,
# so we cant hardlink stuff over nfs easily, skip it for now
#
#cd ${PUBLISH_DIR}
## use idle prio to be friendly, there is no hurry here
## give hardlink only subset of subdirs, to save time. There is nothing to link in others.
#ionice -c 3 /usr/sbin/hardlink -c -v ${_DEST}/licenses ${_DEST}/sdk-data ${_DEST}/sources
#exit 0

