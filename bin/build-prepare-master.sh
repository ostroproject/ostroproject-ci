#!/bin/bash -xeu
#
# build-prepare-master.sh: preparation for build on CI master
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

# common script called from build jobs, runs on CI master, prepares for build:
# - defines DEST, i.e. the results location
# - creates tarball for worker, advancing to repo dir first
#   (this differs by job, can be . for regular job, or $CI_COMBO_DIR/iot-os for meta layer jobs) 
#   note: Clones a fresh directory to avoid untracked workspace files
# - creates env.properties defining params used by other jobs

REPODIR=$1

# if suffix given, it goes after CI_PUBLISH_NAME in dir name
_SUFFIX=""
[ -v PUBLISH_DIR_SUFFIX ] && _SUFFIX=${PUBLISH_DIR_SUFFIX}

# certain builds (pull request) have sequence number, use this if present
_POSTFIX_DIR=""
pr_name_suffix=_pull-requests
if [[ ${JOB_NAME} == *${pr_name_suffix}* ]]; then
  # PR jobs have always _pull-requests as part of jobname.
  if [ -v ghprbPullId ]; then
    _POSTFIX_DIR="/${ghprbPullId}"
  fi
fi

[ -n "${REPODIR}" ] && cd $REPODIR
_tball=${BUILD_TAG}_${BUILD_TIMESTAMP}.tar.gz
rm -fr .tmp
git clone . .tmp/
cd .tmp
git repack -a -d
tar cfz ${HOME}/${CI_EXPORT}/${_tball} .
cd ..
rm -fr .tmp

# remove previous testinfo files, builders will copy new ones to this workspace
rm -f ${WORKSPACE}/*.testinfo.csv

# create env.properties
PROPFILE=${WORKSPACE}/env.properties

# if ghprbTargetBranch is defined, it contains branch given by GH PR API
# In other cases, we try to detect from job name.
# ghprb jobs that are retriggered, will restore most of ghprb context from locally stored file.

if [ -v ghprbTargetBranch ]; then
  _BRANCH=${ghprbTargetBranch}
  # note, this hard-coded list needs update when new CI branches are supported
  if [ ${_BRANCH} != "master" -a ${_BRANCH} != "1.0.M2" ]; then
    echo "CI-WARNING *** : CI cant match ghprbTargetBranch ${_BRANCH} to supported CI branches!!!"
    echo "CI-WARNING *** : Falling back with CI_BRANCH set to master"
    _BRANCH=master
  fi
else
  _BUILD_JOB=${BUILD_TAG%"-${BUILD_NUMBER}"}
  _BRANCH=`echo ${_BUILD_JOB} | awk -F'_' '{print $NF}'`
  if [ "$_BRANCH" = "pull-requests" ]; then
    echo "CI-WARNING *** : Pull-request job without CI_BRANCH from Github context, falling back to master"
    _BRANCH=master
  fi
fi

CI_BUILD_ID=${BUILD_TIMESTAMP}-build-${BUILD_NUMBER}
_PDIR=${CI_PUBLISH_NAME}${_SUFFIX}${_POSTFIX_DIR}

# these values are always in prop file. Can be set to value in job header.
cat > $PROPFILE << EOF
CI_BUILD_ID=${CI_BUILD_ID}
CI_PUBLISH_NAME=${CI_PUBLISH_NAME}
CI_TARBALL=${_tball}
PUBLISH_DIR=${STORE_BASE}/builds/${_PDIR}
RSYNC_PUBLISH_DIR=${CI_PUBLISH_NAME}${_SUFFIX}${_POSTFIX_DIR}
PARENT_JOB_NAME=${JOB_NAME}
PARENT_BUILD_TAG=${BUILD_TAG}
PARENT_BUILD_TIMESTAMP=${BUILD_TIMESTAMP}
CI_BRANCH=${_BRANCH}
CI_EXPORT=${CI_EXPORT}
CI_TESTRESULTS_CACHE=${CI_TESTRESULTS_CACHE}
EOF

# these values are optional and go into prop.file only when defined in job header
if [ -v CI_COMMIT_BUILDHISTORY ]; then
   echo CI_COMMIT_BUILDHISTORY=${CI_COMMIT_BUILDHISTORY} >> $PROPFILE
fi
if [ -v CI_COMMIT_PRSERVER ]; then
   echo CI_COMMIT_PRSERVER=${CI_COMMIT_PRSERVER} >> $PROPFILE
fi
if [ -v CI_ARCHIVER_MODE ]; then
   echo CI_ARCHIVER_MODE=${CI_ARCHIVER_MODE} >> $PROPFILE
fi
if [ -v SLOW_MODE ]; then
  echo SLOW_MODE=${SLOW_MODE} >> $PROPFILE
fi
if [ -v CI_POPULATE_SSTATE ]; then
  echo CI_POPULATE_SSTATE=${CI_POPULATE_SSTATE} >> $PROPFILE
fi
if [ -v PUBLISH_PACKAGES ]; then
  echo PUBLISH_PACKAGES=${PUBLISH_PACKAGES} >> $PROPFILE
fi
if [ -v CI_REUSE_SSTATE ]; then
  echo CI_REUSE_SSTATE=${CI_REUSE_SSTATE} >> $PROPFILE
fi
if [ -v CI_CREATE_GIT_ARCHIVE ]; then
  echo CI_CREATE_GIT_ARCHIVE=${CI_CREATE_GIT_ARCHIVE} >> $PROPFILE
fi

echo "Original $PROPFILE:"
echo "===================================="
sort $PROPFILE
cp ${PROPFILE} ${HOME}/${CI_EXPORT}/env.properties.${CI_BUILD_ID}
