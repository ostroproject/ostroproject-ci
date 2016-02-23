#!/bin/sh -xeu
#
# build-publish-ostro-xt.sh: publish ostro-xt build to external dnl site.
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

# Variables from parent job after which this job was triggered,
# have been inserted to env as PARENT_variable.
# We use parent variables to select one build to publish.
CI_PUBLISH_NAME=ostro-os-xt
_SRC_BASE=/srv/ostro/ostro-os-xt
_DEST_BASE=rsync://localhost:8873/content_RW_ostro
CI_BUILD_ID=${PARENT_BUILD_TIMESTAMP}-build-${PARENT_BUILD_NUMBER}

# show all variables:
env |sort

# This runs on a ostro-bld-XX worker, src data comes remotely from NFS server
#########################################################
# publish images to external dnl site.

_SRC=${_SRC_BASE}/builds/${PARENT_JOB_NAME}/${CI_BUILD_ID}
_DEST=${_DEST_BASE}/builds/${CI_PUBLISH_NAME}

# copy images,licesnses,sdk,sdk-data,sources
# exclude: .buildstats/, .stamps/,detailed-logs/,isafw/,
#           IA debug related
rsync -avzESH \
      --exclude=.buildstats/ \
      --exclude=.stamps/ \
      --exclude=detailed-logs/ \
      --exclude=isafw/ \
      --exclude=images/*/bzImage* \
      --exclude=images/*/*initramfs* \
      --exclude=images/*/microcode* \
      --exclude=images/*/*.stub \
      --stats \
      ${_SRC} ${_DEST}/

# copy update data:
_SRC=${_SRC_BASE}/updates/${CI_PUBLISH_NAME}
_DEST=${_DEST_BASE}/updates/${CI_PUBLISH_NAME}
rsync -avzESH --stats \
      ${_SRC}/* ${_DEST}/

# sync latest symlink. Syncing all builds covers also symlink.
# Below line needs to be enabled if syncing exactly one build is enabled again.
rsync -avE ${_SRC_BASE}/builds/${PARENT_JOB_NAME}/latest ${_DEST}/

#########################################################
# publish sources cache to external dnl site
_SRC=${_SRC_BASE}/bb-cache/sources
_DEST=${_DEST_BASE}/mirror
rsync -avz --stats --size-only --exclude=images/edison/.nfs* --exclude=*.lock ${_SRC} ${_DEST}/
 
#########################################################
# copy new buildhistory contents
_SRC=${_SRC_BASE}/buildhistory
_DEST=${_DEST_BASE}/buildhistory/${CI_PUBLISH_NAME}.git
rsync -avz --delete --delete-after --stats ${_SRC}/* ${_DEST}/

#########################################################
# publish sstate to external dnl site.
_SRC=${_SRC_BASE}/bb-cache/sstate
_DEST=${_DEST_BASE}/sstate/${CI_PUBLISH_NAME}
rsync -avz --stats ${_SRC}/* ${_DEST}/
