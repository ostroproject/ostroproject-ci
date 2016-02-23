#!/bin/bash -xeu
#
# pr_serv_stop.sh: stop PR server
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

# read in config values of the build
if [ -f ${STORE_BASE}/${CI_WORKERS_CACHE}/env.properties.${CI_BUILD_ID} ]; then
  . ${STORE_BASE}/${CI_WORKERS_CACHE}/env.properties.${CI_BUILD_ID}
fi

if [ ! -v PRSERVER_PORT ]; then
  exit 0
fi

# prserver code runs in unique directory
_pr_path=${PRSERVER_INSTANCE_PATH}
_master_file=${PRSERVER_BASEPATH}/${CI_BRANCH}/$PRSERVER_FILE
_working_file=${_pr_path}/$PRSERVER_FILE

###################################################
# stop server
${_pr_path}/bitbake/bin/bitbake-prserv --stop --host=${COORD_ADDR} --port=${PRSERVER_PORT} \
      --file ${_working_file} \
      --log=${_pr_path}/$PRSERVER_LOG \
      --loglevel=$PRSERVER_LOGLEVEL

if [ -v CI_COMMIT_PRSERVER ]; then
  # master case: PR server dbase file overwritten with new file from workspace,
  # saving previous master file as snapshot
  mv -f ${_master_file} ${_master_file}.before.${BUILD_NUMBER}
  ls -l ${_pr_path}/
  cp -v ${_working_file} ${_master_file}
fi
