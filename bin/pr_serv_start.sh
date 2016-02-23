#!/bin/bash -xeu
#
# pr_serv_start.sh: start PR server
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

# we need to get pr server code, we try to extract it from source tarball.

. ${STORE_BASE}/${CI_WORKERS_CACHE}/env.properties.${CI_BUILD_ID}

if [ ! -v PRSERVER_PORT ]; then
  exit 0
fi
echo "PRSERVER_PORT=$PRSERVER_PORT" >> ${STORE_BASE}/${CI_WORKERS_CACHE}/env.properties.${CI_BUILD_ID}

_pr_path=`mktemp -d --tmpdir=${WORKSPACE} prserver-instance-XXXXX`
echo "PRSERVER_INSTANCE_PATH=${_pr_path}" >> ${STORE_BASE}/${CI_WORKERS_CACHE}/env.properties.${CI_BUILD_ID}
cd ${_pr_path}

tar xfz ${STORE_BASE}/${CI_WORKERS_CACHE}/${CI_TARBALL} ./bitbake || tar xfz ${CI_WORKERS_CACHE}/${CI_TARBALL} ./${CI_COMBO_DIR}/${DISTRO_NAME}/bitbake
[ -d ./${CI_COMBO_DIR} ] && mv -v ./${CI_COMBO_DIR}/${DISTRO_NAME}/bitbake ./

_master_file=${PRSERVER_BASEPATH}/${CI_BRANCH}/$PRSERVER_FILE
_working_file=${_pr_path}/$PRSERVER_FILE

# Copy master PR db into job workspace during build, show file size
cp -v ${_master_file} ${_working_file}
ls -l ${_pr_path}/
###################################################
# start server
# using jenkins BUILD_ID trick to achieve running daemon after job completion
rm -f ${_pr_path}/$PRSERVER_LOG
BUILD_ID=DontKillMe nohup ./bitbake/bin/bitbake-prserv --start --host=${COORD_ADDR} --port=${PRSERVER_PORT} \
      --file ${_working_file} \
      --log=${_pr_path}/$PRSERVER_LOG \
      --loglevel=$PRSERVER_LOGLEVEL

