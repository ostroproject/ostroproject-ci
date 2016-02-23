#!/bin/bash -xeu
#
# build-image.sh: Build image of one MACHINE
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
# Catch errors in pipelines
set -o pipefail

rm -f ${WORKSPACE}/env.properties.* ${WORKSPACE}/*.testinfo.csv
# get extended env.properties
if [ -f ${STORE_BASE}/${CI_WORKERS_CACHE}/env.properties.${CI_BUILD_ID} ]; then
  # in new CI this is mounted to workers over NFS
  cp ${STORE_BASE}/${CI_WORKERS_CACHE}/env.properties.${CI_BUILD_ID} .
else
  rsync rsync://${COORD_ADDR}/${CI_WORKERS_CACHE}/env.properties.${CI_BUILD_ID} .
fi
. ./env.properties.${CI_BUILD_ID}

_started=`date +"%s"`
TARGET_MACHINE=`echo ${JOB_NAME} | awk -F'_' '{print $NF}'`
_PARENT_BUILD_NUMBER=`echo ${CI_BUILD_ID} | awk -F'-' '{print $NF}'`
_RSYNC_DEST=${STORE_ADDR}/builds/${RSYNC_PUBLISH_DIR}/${CI_BUILD_ID}

rm -fr ${DISTRO_NAME}
# rm previous build dir(s)
rm -fr /tmp/ci-empty
mkdir -p /tmp/ci-empty
_bdir=${NODE_NAME}-slot-${EXECUTOR_NUMBER}
# ls may return non-zero if no dir, dont allow this break job
set +e
_prevdirs=`ls -d ${HOME}/${_bdir}-*`
for _prevd in ${_prevdirs}; do
  rsync -r --delete /tmp/ci-empty/ ${_prevd}/
  rm -fr ${_prevd}
done
set -e

# create new dir with unique name
_SPACETEMP=`mktemp -d --tmpdir=${HOME} ${_bdir}-XXXXX`
_SPACE=${_SPACETEMP}/${DISTRO_NAME}
mkdir -p ${_SPACE}
ln -s ${_SPACE} ${DISTRO_NAME}
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
_CONFDIR="$_BUILDDIR/conf"

# ########################################
# Initialize the BitBake build environment
#
# Just be sure that the build dir is cleaned up
if [ -e "$_BUILDDIR" ]; then
    echo "Removing $_BUILDDIR"
    rm -rf "$_BUILDDIR"
fi

LOG=$WORKSPACE/$DISTRO_NAME/bitbake-${TARGET_MACHINE}-${CI_BUILD_ID}.log
CI_GIT_COMMIT=`git rev-parse HEAD`
echo "*** Build $CI_BUILD_ID of $CI_PUBLISH_NAME, git revision: ${CI_GIT_COMMIT}" > $LOG

# Create build dir
set +u
( . ./oe-init-build-env "$_BUILDDIR" ) >>$LOG
set -u

BUILD_ID=${CI_BUILD_ID}
BB_ENV_EXTRAWHITE=""
_DL_DIR=${BB_CACHE_BASE}/sources

if [ -v CI_POPULATE_SSTATE ]; then
  # product build will generate material to be added to global sstate
  _SSTATE=${BB_CACHE_BASE}/${PARENT_JOB_NAME}/sstate.${CI_BUILD_ID}
  mkdir -p ${_SSTATE}
elif [ -v CI_REUSE_SSTATE ]; then
  # PR jobs may keep and share same sstate for PR lifetime
  # Note, we re-use RSYNC dir name to construct path with project-PRnum in it
  _SSTATE=${BB_CACHE_BASE}/${RSYNC_PUBLISH_DIR}
  mkdir -p ${_SSTATE}
else
  SSTATE_LOCAL=${HOME}/sstate-${EXECUTOR_NUMBER}
  mkdir -p ${SSTATE_LOCAL}
  _SSTATE=${SSTATE_LOCAL}
  # clean locally created files from local sstate cache
  find ${_SSTATE} -mindepth 2 -type f -exec rm -f {} \;
fi

# Create auto.conf
if [ -f meta-${DISTRO_SNAME}/conf/distro/include/ostroproject-ci.inc ]; then
  cat > "$_CONFDIR/auto.conf" << EOF
include conf/distro/include/ostroproject-ci.inc
EOF
else
  cp -v ${WORKSPACE}/ci/conf/ostroproject-ci.inc ${_CONFDIR}/auto.conf
fi

if [ -v CI_ARCHIVER_MODE ]; then
cat >> "$_CONFDIR/auto.conf" << EOF
INHERIT += "archiver"
ARCHIVER_MODE[src] = "original"
ARCHIVER_MODE[diff] = "1"
ARCHIVER_MODE[recipe] = "1"
EOF
fi

# parallel run tunables expected to be defined in builder properties.
# Some defaults are also set here for case of missing node properties.
PMAKE=8
[ -v CI_PMAKE ] && PMAKE=${CI_PMAKE}
NTHR=12
[ -v CI_NTHREAD ] && NTHR=${CI_NTHREAD}

cat >> "$_CONFDIR/auto.conf" << EOF
BB_NUMBER_THREADS = "${NTHR}"
BB_NUMBER_PARSE_THREADS = "${NTHR}"
EOF

# SLOW_MODE for cross-checking in nightly build: no sstate, no parallel make
if [ -v SLOW_MODE ]; then
  BB_NO_CACHE="--no-setscene"
  cat >> "$_CONFDIR/auto.conf" << EOF
PARALLEL_MAKE = ""
EOF
else
  SSTATE_MIRROR_PATH=http://${COORD_ADDR}/download/${DISTRO_NAME}/bb-cache/sstate/PATH
  BB_NO_CACHE=""
  cat >> "$_CONFDIR/auto.conf" << EOF
SSTATE_MIRRORS ?= "file://.* ${SSTATE_MIRROR_PATH}"
SSTATE_DIR ?= "${_SSTATE}"
PARALLEL_MAKE = "-j ${PMAKE}"
EOF
fi

# Prepare for buildhistory generation
# For main jobs CI_COMMIT_BUILDHISTORY is true, we commit buildhistory in
# BH branch, name of which is composed from parent job name and machine.
# In other jobs than master, we do not commit back to BH repo.
_BH_JOBNAME=${PARENT_JOB_NAME}
# all BH is in one git repo, in separate machine-specific branches
BUILDHISTORY_TMP=${WORKSPACE}/buildhistory
BUILDHISTORY_BRANCH="${_BH_JOBNAME}/${TARGET_MACHINE}"

# Clone directory
rm -fr ${BUILDHISTORY_TMP}
#git clone --branch ${TARGET_MACHINE} --single-branch ${BUILDHISTORY_MASTER} ${BUILDHISTORY_LOCAL}
git clone ${STORE_BASE}/buildhistory ${BUILDHISTORY_TMP}
pushd ${BUILDHISTORY_TMP}
if ! git checkout ${BUILDHISTORY_BRANCH} --; then
  git checkout --orphan ${BUILDHISTORY_BRANCH} --;
  git reset
  git clean -fdx
fi
if [ -v CI_COMMIT_BUILDHISTORY ]; then
  git rm --ignore-unmatch -rf .
fi
popd

## Add DL_DIR, MACHINE, build history, PR server settings to conf
cat >> "$_CONFDIR/auto.conf" << EOF
MACHINE = "$TARGET_MACHINE"
DL_DIR = "${_DL_DIR}"
BUILDHISTORY_DIR ?= "${BUILDHISTORY_TMP}"
PRSERV_HOST = "${COORD_ADDR}:${PRSERVER_PORT}"
EOF

# ########################################
# Show auto.conf to get it documented in build log
echo "Contents of $_CONFDIR/auto.conf:"
echo "========================================"
sort ${_CONFDIR}/auto.conf
echo "========================================"

# ########################################
# Do the actual build: images, sdk, packages, testdata
#
set +u

# Initialize bitbake
. ./oe-init-build-env "$_BUILDDIR" >> $LOG

export BUILD_ID=${CI_BUILD_ID}
export BB_ENV_EXTRAWHITE="$BB_ENV_EXTRAWHITE BUILD_ID"
_BRESULT=tmp-glibc

#BB_VERBOSE="-v"
BB_VERBOSE=""

# Let's try to fetch build targets from configuration files
bitbake -e >bb_e_out 2>bb_e_err
grep -E "^OSTROPROJECT_CI" bb_e_out > ${WORKSPACE}/ostroproject_ci_vars
_bitbake_targets=""
OSTROPROJECT_CI_BUILD_TARGETS_TASK=""
OSTROPROJECT_CI_SDK_TARGETS_TASK="do_populate_sdk"
OSTROPROJECT_CI_ESDK_TARGETS_TASK="do_populate_sdk_ext"
OSTROPROJECT_CI_TEST_EXPORT_TARGETS_TASK="do_test_iot_export"
for ci_var in `perl -pe "s/^([A-Z_]+)=.+/\1/g" ${WORKSPACE}/ostroproject_ci_vars`; do
  ci_var_task="${ci_var}_TASK"
  if [ -v "$ci_var_task" ]; then
    for img in `grep ${ci_var} ${WORKSPACE}/ostroproject_ci_vars | perl -pe 's/.+="(.*)"/\1/g; s/[^ a-zA-Z0-9_-]//g'`; do
      if [ -n "${!ci_var_task}" ]; then
        _bitbake_targets="$_bitbake_targets $img:${!ci_var_task}"
      else
        _bitbake_targets="$_bitbake_targets $img"
      fi
    done
  fi
done
if [ -z "$_bitbake_targets" ]; then
  # Autodetection failed. Assume default historical targets.
  # Currently, we build statically set targets:
  _bitbake_targets="${DISTRO_SNAME}-image:do_build ${DISTRO_SNAME}-image-dev:do_build ${DISTRO_SNAME}-image:do_populate_sdk_ext ${DISTRO_SNAME}-image:do_test_iot_export"
fi

echo "*** bitbake $BB_VERBOSE $BB_NO_CACHE ${_bitbake_targets}" >> $LOG
bitbake $BB_VERBOSE $BB_NO_CACHE ${_bitbake_targets} | tee -a $LOG

# ########################################
# Publish results
#
set -u
_DEPL=${_BRESULT}/deploy
[ -d ${_DEPL}/images ] &&   rsync -aES --exclude=README_-_DO_NOT_DELETE_FILES_IN_THIS_DIRECTORY.txt ${_DEPL}/images/${TARGET_MACHINE} ${_RSYNC_DEST}/images/
# XXX licenses,sources sync may cause race from multiple workers as there are common files
[ -d ${_DEPL}/licenses ] && rsync -aE --ignore-existing ${_DEPL}/licenses ${_RSYNC_DEST}/
[ -d ${_DEPL}/sources ] &&  rsync -aE --ignore-existing ${_DEPL}/sources ${_RSYNC_DEST}/
[ -d ${_DEPL}/tools ] && rsync -aE --ignore-existing ${_DEPL}/tools ${_RSYNC_DEST}/
if [ -v PUBLISH_PACKAGES ]; then
  # be flexible: bitbake may produce rpm/ipk/deb packages
  [ -d ${_DEPL}/rpm ] &&    rsync -aE ${_DEPL}/rpm ${_RSYNC_DEST}/
  [ -d ${_DEPL}/ipk ] &&    rsync -aE ${_DEPL}/ipk ${_RSYNC_DEST}/
  [ -d ${_DEPL}/deb ] &&    rsync -aE ${_DEPL}/deb ${_RSYNC_DEST}/
fi

# If produced, publish swupd repo to build directory.
# It will be published to real update location during build finalize steps
if [ -d ${_DEPL}/swupd/${TARGET_MACHINE} ]; then
  for s_dir in `find ${_DEPL}/swupd/${TARGET_MACHINE} -maxdepth 2 -name www -type d`; do
    i_dir=`dirname $s_dir`
    i_name=`basename $i_dir`
    # pre-create destination directories
    mkdir -p .swupd/swupd/${TARGET_MACHINE}/$i_name
    rsync -aE --ignore-existing .swupd/swupd ${_RSYNC_DEST}/
    rm -rf .swupd
    rsync -aE $s_dir/* ${_RSYNC_DEST}/swupd/${TARGET_MACHINE}/$i_name/
  done
fi

# call eSDK publish script with destination set to sdk-data/TARGET_MACHINE/
# note: script name is dynamic, use it via wildard. NB! works while there is only one sdk/*-toolchain-ext*.sh
[ -d ${_DEPL}/sdk ] && ${_SPACE}/scripts/oe-publish-sdk ${_DEPL}/sdk/*-toolchain-ext*.sh ${_DEPL}/sdk-data/${TARGET_MACHINE}/
# publish installer as .sh file to sdk/ and all of sdk-data/
[ -d ${_DEPL}/sdk ] && rsync -aE ${_DEPL}/sdk/*-toolchain-ext*.sh ${_RSYNC_DEST}/sdk/${TARGET_MACHINE}/
[ -d ${_DEPL}/sdk-data/${TARGET_MACHINE} ] && rsync -aE ${_DEPL}/sdk-data/${TARGET_MACHINE} ${_RSYNC_DEST}/sdk-data/
# Test run data
set +e
OSTROPROJECT_CI_TEST_RUNS=`grep OSTROPROJECT_CI_TEST_RUNS= ${WORKSPACE}/ostroproject_ci_vars | perl -pe 's/.+="(.*)"/\1/g; s/[^ ,.a-zA-Z0-9_-]//g'`
if [ -z "$OSTROPROJECT_CI_TEST_RUNS" ]; then
  # Legacy, default test target and data
  echo "${DISTRO_SNAME}-image,iot-testsuite.tar.gz,iot-testfiles.${TARGET_MACHINE}.tar.gz,${TARGET_MACHINE}" > ${WORKSPACE}/${TARGET_MACHINE}.testinfo.csv
else
  for row in "$OSTROPROJECT_CI_TEST_RUNS"; do
    echo $row >> ${WORKSPACE}/${TARGET_MACHINE}.testinfo.csv
  done
fi
# Copy detailed build logs
rsync -qzr --prune-empty-dirs --include "log.*" --include "*/" --exclude "*" ${_BRESULT}/work*/* ${_RSYNC_DEST}/detailed-logs/${TARGET_MACHINE}/
set -e
[ -d ${_DEPL}/testsuite ] &&  rsync -aE ${_DEPL}/testsuite/* ${_RSYNC_DEST}/testsuite/${TARGET_MACHINE}/
## for debugging signatures: publish stamps
[ -d ${_BRESULT}/stamps ] && rsync -aE ${_BRESULT}/stamps/* ${_RSYNC_DEST}/.stamps/${TARGET_MACHINE}/
# publish isafw-report
[ -n "$(find ${_BRESULT}/log -maxdepth 1 -name 'isafw*' -print -quit)" ] && rsync -aE ${_BRESULT}/log/isafw-report*/* ${_RSYNC_DEST}/isafw/${TARGET_MACHINE}/ --exclude internal
# XXX for debug: publish isafw-logs
[ -n "$(find ${_BRESULT}/log -maxdepth 1 -name 'isafw*' -print -quit)" ] && rsync -aE ${_BRESULT}/log/isafw-logs ${_RSYNC_DEST}/isafw/${TARGET_MACHINE}/

# ########################################
# Compress and copy bitbake build log to publish area
#
xz -v -k ${LOG}
rsync -azE ${LOG}* ${_RSYNC_DEST}/

# ########################################
# Return to the base dir of the job
#
cd ${WORKSPACE}

# ########################################
# Push buildhistory into machine-specific branch in the master buildhistory
#
if [ -v CI_COMMIT_BUILDHISTORY ]; then
  cd ${BUILDHISTORY_TMP}
  BUILDHISTORY_TAG="${_BH_JOBNAME}/${CI_BUILD_ID}/${CI_GIT_COMMIT}/${TARGET_MACHINE}"
  git tag -a -m "Build #${_PARENT_BUILD_NUMBER} (${PARENT_BUILD_TIMESTAMP}) of ${_BH_JOBNAME} for ${TARGET_MACHINE}" -m "Built from Git revision ${CI_GIT_COMMIT}" ${BUILDHISTORY_TAG} refs/heads/${BUILDHISTORY_BRANCH}

  git push origin refs/heads/${BUILDHISTORY_BRANCH}:refs/heads/${BUILDHISTORY_BRANCH}
  git push origin refs/tags/${BUILDHISTORY_TAG}:refs/tags/${BUILDHISTORY_TAG}
fi

# -e option ensures we reach here if all steps have been good
_completed=`date +"%s"`
_elapsed=$(( (_completed - _started)/60 ))
echo "build-image: SUCCESS machine: ${TARGET_MACHINE} parent: ${PARENT_JOB_NAME} builder: ${_bdir} build-time: ${_elapsed} minutes"
