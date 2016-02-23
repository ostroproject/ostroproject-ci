#!/bin/bash -xeu
#
# upstream-monitor.sh: create or update PR based on upstream changes
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

PR_CREATION_BRANCH=ci-$JOB_NAME

BASE_BRANCH=`echo $JOB_NAME | sed -E 's/upstream-.*-(.+)/\1/'`

if [ ! -d .ci ]; then
  mkdir .ci
fi

cd .ci

# Delete all local branches from the git-repositories in .ci
for f in `ls .`; do
  if [ -d "$f" -a -d "$f/.git" ]; then
    pushd "$f"
      # Detach HEAD and remove branches
      git checkout HEAD^0
      for branch in `git branch | grep -v '*'`; do
        git branch -D $branch
      done
      # Force sync of remote config from polling job to cache area
      if [ -f "$WORKSPACE/$f/.git/config" ]; then
        git config remote.origin.url `git config -f $WORKSPACE/$f/.git/config --get remote.origin.url`
      fi
    popd
  fi
done

# Clone/update distro repo
if [ ! -d ${DISTRO_NAME} ]; then
  REF=""
  if [ -d "${WORKSPACE}/${DISTRO_NAME}" ]; then
    REF="--reference ${WORKSPACE}/${DISTRO_NAME}"
  fi
  git clone git@github.com:${OSTRO_GITHUB_ORG}/${DISTRO_NAME} ${REF}
  cd ${DISTRO_NAME}
  git checkout $BASE_BRANCH
else
  cd ${DISTRO_NAME}
  git fetch --all
  git checkout $BASE_BRANCH
  git reset --hard origin/$BASE_BRANCH
fi

if [ -x "${WORKSPACE}/openembedded-core/scripts/combo-layer" ]; then
  # Use latest and greatest combo-layer utility
  COMBOLAYER=${WORKSPACE}/openembedded-core/scripts/combo-layer
elif [ -x "./scripts/combolayer" ]; then
  COMBOLAYER=./scripts/combolayer
else
  echo "Error: combo-layer utility not found!"
  exit 1
fi

cp -u ./conf/combo-layer-local-sample.conf ./conf/combo-layer-local.conf
${COMBOLAYER} init
git checkout -B ${PR_CREATION_BRANCH}
${COMBOLAYER} update

# Update last commit with our custom message
git commit --amend -m "${DISTRO_NAME} CI: pull in the latest changes" --author "${DISTRO_NAME} CI <ci@ostroproject.org>"

# fetch with prune to delete remote-tracking branches that have gone away on remote
git fetch --all --prune

# push update and/or create PR based on presence of remote branch and git diff
#set +e
our_pr="`git show-ref | grep refs/remotes/origin/${PR_CREATION_BRANCH} || true`"
if [ -n "$our_pr" ]; then
  gdiff="`git diff remotes/origin/${PR_CREATION_BRANCH} ${PR_CREATION_BRANCH}`"
else
  gdiff=""
fi

if [ -z "$our_pr" -o -n "$gdiff" ]; then
  git push -f origin ${PR_CREATION_BRANCH}:${PR_CREATION_BRANCH}
  h_pr="`hub issue | grep https://github.com/${OSTRO_GITHUB_ORG}/${DISTRO_NAME}/pull | grep jenkins-$JOB_NAME || true`"
  [ -z "$h_pr" ] && hub pull-request -m "${BUILD_TAG}" -h ${PR_CREATION_BRANCH} -b $BASE_BRANCH || true
fi
