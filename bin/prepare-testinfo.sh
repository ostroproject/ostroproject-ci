#!/bin/bash -xeu
#
# prepare-testinfo.sh: get images testing info and combine
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

# When this script starts, we are in master, toplevel job WORKSPACE.
# Builder job copied testinfo files here after build complete.
# Source info (_sname) files are grouped by builders.
# We re-group testinfo lines by image names and create _dname files.
# We copy testruns.csv file to CI cache where retest job can use it.
# A tester job is started based on _dname file presence, and one such file is fed to tester job.

# get CI_BUILD_ID from properties file as this is not in toplevel shell env
. ./env.properties

_sname=testinfo.csv
_dname=testruns.csv

rm -f *.${_dname}
# Find out all image names mentioned in testinfo files created by builders:
images=`cat *.${_sname} | awk -F, '{print $1}' |sort |uniq`
# Create a testruns file per image name, which will contain info about MACHINEs and testsuites
for img in $images; do
  echo "Creating ${img}.${_dname}"
  cat *.${_sname} |awk -v img=${img} -F, '{if($1==img) print}' > ${img}.${_dname}
  # copy img.testruns.csv to CI export cache where retest job can get it.
  cp ${img}.${_dname} ${HOME}/${CI_EXPORT}/${img}.${_dname}.${CI_BUILD_ID}
done
