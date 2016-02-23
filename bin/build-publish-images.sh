#!/bin/sh -xeu
#
# build-publish-images.sh: publish build results to external dnl site.
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
# This runs on workers coordinator host where build results are
# collected after workers build jobs
#

_SRC=${STORE_BASE}/builds/${CI_PUBLISH_NAME}/${CI_BUILD_ID}
_DEST=rsync://localhost:8873/content_RW_ostro/builds/${CI_PUBLISH_NAME}

# copy images,licesnses,sdk,sdk-data,sources
# exclude: edison files not needed for flashing, plain dsk files,
# .stamps/,detailed-logs/,isafw/,
# sdk-data/sstate, IA debug related, beaglebone jffs2 files
rsync -avzESH \
      --exclude=images/edison/flashall \
      --exclude=images/edison/ifwi \
      --exclude=images/edison/u-boot-envs \
      --exclude=images/edison/*.ext4 \
      --exclude=images/edison/*.tar \
      --exclude=images/edison/*.tar.gz \
      --exclude=images/edison/*.rootfs.tar.bz2 \
      --exclude=images/edison/*edison.tar.bz2 \
      --exclude=images/edison/*.hddimg \
      --exclude=ostro-image*.dsk \
      --exclude=${CI_BUILD_ID}/.stamps/ \
      --exclude=${CI_BUILD_ID}/detailed-logs/ \
      --exclude=${CI_BUILD_ID}/isafw/ \
      --exclude=${CI_BUILD_ID}/sdk-data/*/sstate-cache \
      --exclude=images/*/EFI/ \
      --exclude=images/*/bzImage* \
      --exclude=images/*/*initramfs* \
      --exclude=images/*/microcode* \
      --exclude=images/*/*.stub \
      ${_SRC} ${_DEST}/

# sync latest symlink
rsync -avE ${STORE_BASE}/builds/${CI_PUBLISH_NAME}/latest ${_DEST}/
