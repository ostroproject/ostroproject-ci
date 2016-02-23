#!/bin/sh -xue
#
# make_new_release.sh
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

CWD=`dirname $0`
CWD=`realpath $CWD`

IMAGE_NAME="ostro-image-swupd"
DOWNLOADS_URL=http://${COORD_ADDR}/download/builds/ostro-os
OSTRO_VER=`curl -f -sS ${DOWNLOADS_URL}/latest/version`

if [ $? -gt 0 ]; then
    echo "Can't get latest Ostro version. Exiting..."
    exit
fi

function generate_repo {
    touch $CWD/storage/$2/image/latest.version
    docker run --rm=true --privileged \
               -v $CWD/storage/$2:/var/lib/update \
               ostro-swupd-server /bin/sh /home/clrbuilder/projects/process_rootfs.sh $1
    echo $1 > $CWD/storage/$2/image/latest.version
    mkdir -p $CWD/storage/$2/www/version/format3
    echo $1 > $CWD/storage/$2/www/version/format3/latest
    rsync -rl $CWD/storage/$2/www/$1 rsync://${COORD_ADDR}/swupd/$2
    rsync -rl --delete-excluded $CWD/storage/$2/www/version rsync://${COORD_ADDR}/swupd/$2
}

BUILD_NUM=`echo $OSTRO_VER | awk -F "-" '{print $7}'`

VER="${BUILD_NUM}0"

mkdir -p $CWD/storage
CURRENT_VER=`touch $CWD/storage/version.latest && cat $CWD/storage/version.latest`
if [ $VER -gt "0$CURRENT_VER" ]; then
    echo "$VER > $CURRENT_VER -> UPDATING"
else
    echo "Nothing new. Exiting..."
    exit
fi

echo Latest VERSION: $VER

echo "Handle rootfs in tarballs"
MACHINES="beaglebone edison"
#MACHINES=""
for machine in $MACHINES
do
    echo "       $machine"
    rm -rf $CWD/mounts
    mkdir -p $CWD/mounts
    IMG_URL=${DOWNLOADS_URL}/${OSTRO_VER}/images/${machine}/${IMAGE_NAME}-${machine}.tar.bz2
    LATEST_ROOTFS="${IMAGE_NAME}-${machine}-${VER}.tar.bz2"
    curl -s -o $CWD/mounts/$LATEST_ROOTFS $IMG_URL

    mkdir -p $CWD/storage/$machine/image/$VER/os-core
    mkdir -p $CWD/storage/$machine/www
    tar xjf $CWD/mounts/$LATEST_ROOTFS -C $CWD/storage/$machine/image/$VER/os-core/
    generate_repo $VER $machine
done

echo "Handle rootfs in disk images"
MACHINES="intel-corei7-64 intel-quark"
#MACHINES="intel-corei7-64"
for machine in $MACHINES
do
    echo "       $machine"
    rm -rf $CWD/mounts
    mkdir -p $CWD/mounts
    IMG_URL=${DOWNLOADS_URL}/${OSTRO_VER}/images/${machine}/${IMAGE_NAME}-${machine}.dsk.xz
    LATEST_IMG="${IMAGE_NAME}-${machine}-${VER}.dsk"
    LAYOUT_URL=${DOWNLOADS_URL}/${OSTRO_VER}/images/${machine}/${IMAGE_NAME}-${machine}-disk-layout.json
    LAYOUT_FILE="${IMAGE_NAME}-${machine}-${VER}-disk-layout.json"
    curl -s -o $CWD/mounts/${LATEST_IMG}.xz $IMG_URL
    curl -s -o $CWD/mounts/${LAYOUT_FILE} $LAYOUT_URL
    unxz $CWD/mounts/${LATEST_IMG}.xz
    sh -xe $CWD/extract_rootfs.sh $CWD/mounts/$LATEST_IMG  $CWD/storage/$machine $VER $CWD/mounts/$LAYOUT_FILE
    generate_repo $VER $machine
done

echo $VER > $CWD/storage/version.latest
