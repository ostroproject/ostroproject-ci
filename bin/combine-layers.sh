#!/bin/bash -xeu
#
# combine-layers.sh: create combined tree using combo-layer tool
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

# This is common script to be called from meta-* jobs
# It checks out/updates the release repository in ./$CI_COMBO_DIR, combines with current one.
#

Cleanup() {
  # delete local branch
  cd ${WORKSPACE}
  git checkout --detach
  git branch -d $BUILD_TAG
}

trap Cleanup INT TERM EXIT ABRT

publishname=$1
# while in jobs workspace, find out CID from sha1 for later use in combo-layer
if [ -v sha1 ]; then
  CID=`git rev-parse ${sha1}`
else
  CID=$GIT_COMMIT
fi
# sanity check that PR is properly rebased:
if [ -v ghprbTargetBranch -a -v ghprbActualCommit ]; then
  if ! git merge-base --is-ancestor origin/$ghprbTargetBranch $ghprbActualCommit; then
    echo "CI-Warning ***: PR was not properly rebased"
  fi
fi
# originally, master jobs publishnames do not have _master part,
# means we need to treat differently branch and master names
br1=_1.0.M2
br2=_master
if [[ $publishname == *${br1}* ]]; then
  layer=${publishname%_*}
elif [[ $publishname == *${br2}* ]]; then
  layer=${publishname%_*}
else
  layer=${publishname}
fi

pr_name_suffix=_pull-requests
if [[ ${JOB_NAME} == *${pr_name_suffix}* ]]; then
  # PR jobs have always _pull-requests as part of jobname.
  is_pr=1
  # this defaults to master, but may change to GH PR target br if such exists in combined repo
  use_combined_repo_br=master
else
  # for master-type jobs, branch is coded in job name
  use_combined_repo_br=`echo ${JOB_NAME} | awk -F'_' '{print $NF}'`
fi

## if master has advanced in other workspace, this workspace may lack some commits,
## and jenkins plugin does not check out those. Do it here.
#if [ -v ghprbTargetBranch ]; then
#  _br=${ghprbTargetBranch}
#else
#  if [ -v GIT_BRANCH ]; then
#    _br=`echo ${GIT_BRANCH} | awk -F/ '{print $2}'`
#  else
#    _br=master
#  fi
#fi
#git checkout ${_br}

# create local branch
if [ -v sha1 ]; then
  git checkout -b $BUILD_TAG ${sha1}
else
  git checkout -b $BUILD_TAG $GIT_COMMIT
fi

# check out or update combined repo in subdir=$CI_COMBO_DIR
mkdir -p ${CI_COMBO_DIR}
cd ${CI_COMBO_DIR}
[ ! -d ${DISTRO_NAME} ] && git clone git@github.com:${OSTRO_GITHUB_ORG}/${DISTRO_NAME} --reference ${GIT_MIRROR}/${DISTRO_NAME}.git
cd ${DISTRO_NAME}
git fetch
if [ -v is_pr -a -v ghprbTargetBranch ]; then
  # does combined repo have the branch that was target of PR in metalayer repo?
  if git ls-remote --heads | grep refs/heads/${ghprbTargetBranch} ; then
    use_combined_repo_br=${ghprbTargetBranch}
  fi
fi
git reset --hard origin/${use_combined_repo_br}
# create combo-layer-local.conf from sample, specifying local repo for $layer, local branch
cat ./conf/combo-layer-local-sample.conf | sed "s|local_repo_dir = \.\.\/${layer}$|local_repo_dir = ../../\nbranch = $BUILD_TAG|" > ./conf/combo-layer-local.conf
# run combo-layer to combine layers into one. This creates one local commit.
./scripts/combo-layer update -D -n ${layer}:${CID}
