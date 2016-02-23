#!/bin/bash -u
#
# cleanup-old-builds.sh: Clean up older builds on coordinator
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
shopt -s extglob
#
# Delete build directories based on policy
#

#######################################################################
trim_num_of_dirs_in_parent() {
#
# PRs get rebuilt and we dont want many instances of same PR build
# therefore, keep few newest, delete others
#
parent=$1
basen=`basename $parent`
num_dirs=`find $parent -maxdepth 1 -type d | wc -l`
#echo parent=$parent basen=$basen numdirs=$num_dirs
if [[ $basen =~ ^[0-9]+$ ]]; then
  # dir name contains only digits so it's a PR area
  num_dirs=`find $parent -maxdepth 1 -type d | wc -l`
  if [ $num_dirs -gt ${MAX_BUILDS_OF_SAME_PR} ]; then
    #echo "# Remove extra dirs, leaving ${MAX_BUILDS_OF_SAME_PR}, in $parent"
    dir=`find $parent -mindepth 1 -maxdepth 1 -type d |sort -n | head -n -${MAX_BUILDS_OF_SAME_PR} | head -1`
    if [ -n "$dir" ]; then
      echo "# Remove extra $dir"
      [ $PURGE_DRY_RUN -eq "0" ] && ionice -c 3 rm -fr $dir
    fi
  fi
fi
}
#######################################################################
remove_parent_if_empty() {
#
# remove this dir if:
#  - it has <=1 subdirs (the dir itself is also shown by find)
#  - dir name contains only digits
# This is needed to remove empty PR numbered dirs
# These directories typically contain one broken "latest" symlink only.
#
parent=$1
basen=`basename $parent`
num_dirs=`find $parent -maxdepth 1 -type d | wc -l`
#echo parent=$parent basen=$basen
if [[ $basen =~ ^[0-9]+$ ]]; then
  # dir name contains only digits
  num_dirs=`find $parent -maxdepth 1 -type d | wc -l`
  if [ $num_dirs -le 1 ]; then
    echo "# Remove parent dir $parent"
    rm -f $parent/latest $parent/version
    rmdir $parent
  fi
fi
}

#######################################################################
remove_old() {
#
# walk matching dirs from specified root,
# remove if old enough
#
product=$1
path=$2
maxage=$(($3 * 86400))
keep=$4
fullpath=${STORAGE_BASE}/${product}/builds/$path
echo path:$fullpath maxage:$3 days, keeplatest:$keep
dirlist=`find $fullpath -maxdepth 3 -type d -regextype posix-awk -regex $PURGE_PATTERN`
now=`date +"%s"`
for dir in $dirlist; do
  #echo dir=$dir
  dirn=`dirname $dir`
  basen=`basename $dir`
  latest=$dirn/latest
  if [ -L $latest -a $keep -eq "1" ]; then
    link=`readlink $latest`
    [ "$basen" = "${link%/}" ] && continue
  fi
  datestr=`echo $basen | awk -F_ '{ print $1 }'`
  reltime=`date --date=$datestr +"%s"`
  age=$((now - reltime))
  if [ $((now - reltime)) -gt $maxage ]; then
    echo "# Remove $dir"
    [ $PURGE_DRY_RUN -eq "0" ] && ionice -c 3 rm -fr $dir && remove_parent_if_empty $dirn
  fi
  # parent may have gone away above, but if not, trim extra entries in it
  [ -d $dirn ] && trim_num_of_dirs_in_parent $dirn
done
}

#######################################################################
#. deletion-policy
[ $PURGE_DRY_RUN != 0 ] && echo "Dry run, nothing will be deleted"

# read in policy values
read -a products <<< $PURGE_PRODUCTS
read -a paths <<< $PURGE_PATHS
read -a ages <<< $PURGE_AGES
read -a keep_latest <<< $KEEP_LATEST

echo "======= delete builds based on age policy, or number under same PR ======"
for ((i=0;i<${#paths[@]};i++)); do
  remove_old ${products[$i]} "${paths[$i]}" ${ages[$i]} ${keep_latest[$i]}
done

if [ $PURGE_DRY_RUN -eq "0" ]; then
  echo "======= delete older files from coordinator cache area ======"
  WORKERS_CACHE=${BUILD_STORAGE_BASE}/ci/workers-cache
  find $WORKERS_CACHE -type f -name 'jenkins*pull-req*.tar.gz' -mtime +14 -exec rm -v {} \;
  find $WORKERS_CACHE -type f -name 'jenkins*meta*.tar.gz' -mtime +28 -exec rm -v {} \;
  find $WORKERS_CACHE -type f -name 'jenkins-ostro-os_master-*.tar.gz' -mtime +365 -exec rm -v {} \;
  propfiles=`find $WORKERS_CACHE -type f -name 'env.properties.*' -mtime +60 -print`
  # use chance to remove pr server setup that this env file recorded
  for _pfile in $propfiles; do
    _pr_path=`grep PRSERVER_INSTANCE_PATH $_pfile |awk -F= '{print $2}'`
    if [ -d "${_pr_path}" ]; then
      echo "# Remove PR server setup ${_pr_path}"
      ionice -c 3 rm -fr ${_pr_path}
    fi
    rm -v $_pfile
  done
fi
