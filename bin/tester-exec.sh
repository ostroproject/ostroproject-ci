#!/bin/sh -xue
#
# tester-exec.sh: test one image on a tester
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
COORD_BASE_URL=http://ostroci.ostc/download/ostro-os

# function to test one image, see call point below.
testimg() {
  _IMG_NAME=$1
  TEST_SUITE_FILE=$2
  TEST_CASES_FILE=$3
  _IMG_NAME_MACHINE=${_IMG_NAME}-${MACHINE}

# clean up created per this function call
  rm -f *.xml *.log
  # Get test suite
  wget ${_WGET_OPTS} ${TEST_SUITE_FOLDER_URL}/${TEST_SUITE_FILE}
  wget ${_WGET_OPTS} ${TEST_SUITE_FOLDER_URL}/${TEST_CASES_FILE}
  tar -xzf ${TEST_SUITE_FILE}
  tar -xzf ${TEST_CASES_FILE} -C iottest/
  # Copy local WLAN settings to iottest over example file and chmod to readable
  _WLANCONF=${WORKSPACE}/iottest/oeqa/runtime/sanity/files/config.ini
  cp /home/tester/.config.ini.wlan ${_WLANCONF}
  chmod 644 ${_WLANCONF}

  # Get image(s)
  if [ "${MACHINE}" = "edison" ]; then
    # Workaround for the wifi test bug -- not enabled, left here for possible future activation
    #sed -i "s/oeqa.runtime.sanity.comm_wifi_connect/#oeqa.runtime.sanity.comm_wifi_connect/g" iottest/testplan/iottest.manifest
    EDISON_TAR_FILENAME=${_IMG_NAME_MACHINE}.toflash.tar.bz2
    TEST_IMG_URL=${DIR_FULL_URL}/images/${MACHINE}/${EDISON_TAR_FILENAME}
    wget ${_WGET_OPTS} ${TEST_IMG_URL}
    tar -xf ${EDISON_TAR_FILENAME}
    mv toFlash/* .
    FILENAME=${_IMG_NAME_MACHINE}.ext4
  elif [ "${MACHINE}" = "beaglebone" ]; then
    FILE_DIR="${DIR_FULL_URL}/images/${MACHINE}"
    wget ${_WGET_OPTS} ${FILE_DIR}/MLO
    wget ${_WGET_OPTS} ${FILE_DIR}/u-boot.img
    wget ${_WGET_OPTS} ${FILE_DIR}/zImage
    wget ${_WGET_OPTS} ${FILE_DIR}/zImage-am335x-boneblack.dtb
    FILENAME=${_IMG_NAME_MACHINE}.tar.bz2
    wget ${_WGET_OPTS} ${FILE_DIR}/${FILENAME}

  else
    FN_BASE=${_IMG_NAME_MACHINE}-${CI_BUILD_ID}
    FILENAME=${FN_BASE}.dsk
    FILENAME_BMAP=${FILENAME}.bmap
    FILENAME_XZ=${FILENAME}.xz
    FILENAME_ZIP=${FILENAME}.zip

    set +e
    wget ${_WGET_OPTS} ${DIR_FULL_URL}/images/${MACHINE}/${FN_BASE}-disk-layout.json
    rm -f ${FILENAME_XZ} ${FILENAME_ZIP}
    TEST_IMG_URL=${DIR_FULL_URL}/images/${MACHINE}/${FILENAME_XZ}
    wget ${_WGET_OPTS} ${TEST_IMG_URL}
    TEST_IMG_BMAP_URL=${DIR_FULL_URL}/images/${MACHINE}/${FILENAME_BMAP}
    wget ${_WGET_OPTS} ${TEST_IMG_BMAP_URL}
    if [ -f ${FILENAME_BMAP} ]; then
      echo "Found ${FILENAME_BMAP}"
    fi
    if [ -f ${FILENAME_XZ} ]; then
      echo "Extracting ${FILENAME_XZ}"
      unxz -d ${FILENAME_XZ}
    else
      TEST_IMG_URL=${DIR_FULL_URL}/images/${MACHINE}/${FILENAME_ZIP}
      wget ${_WGET_OPTS} ${TEST_IMG_URL}
      if [ -f ${FILENAME_ZIP} ]; then
        echo "Extracting ${FILENAME_ZIP}"
        unzip ${FILENAME_ZIP}
      else
        echo "No dsk.xz nor dsk.zip image file found, can not continue"
        exit 1
      fi
    fi
    set -e
  fi

  DEVICE=`echo ${JOB_NAME} | awk -F'_' '{print $2}'`

  if [ "${DEVICE}" != "gigabyte" ]; then
    RECORD_ARG="--record"
  else
    RECORD_ARG=""
  fi

  # execute with +e, so that log files are archived even when aft fails
  set +e
  aft ${DEVICE} ${FILENAME} ${RECORD_ARG}
  AFT_EXIT_CODE=$?
  set -e

  tar c --ignore-failed-read results* *.xml *.log | bzip2 -c9 > aft-results-${TEST_SUITE_FILE}.tar.bz2
  return ${AFT_EXIT_CODE}
}

# Start
# Note: this script relies on cleaned workspace (clean it via jenkins job config)

_WGET_OPTS="--no-verbose --no-proxy"
DIR_FULL_URL="${COORD_BASE_URL}/builds/${RSYNC_PUBLISH_DIR}/${CI_BUILD_ID}"
TEST_SUITE_FOLDER_URL="${DIR_FULL_URL}/testsuite/${MACHINE}/"

# process csv file given to tester job by toplevel job, contains image and testsuite information
while IFS=, read _img _tsuite _tdata _mach
do
  [ "${_mach}" = "${MACHINE}" ] && testimg ${_img} ${_tsuite} ${_tdata}
done < testinfo.csv
