#!/bin/bash -xeu
#
# fetch-testresults-into-workspace.sh: get test results
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

# tester copied test results back to master global dir
# when this script starts, we are in WORKSPACE
# XXX this script may need renaming, or whole operation idea of it checking
mkdir -p ${TESTRESULTS_DIR}
rm -fr ${TESTRESULTS_DIR}/*
cp -a ${HOME}/${CI_TESTRESULTS_CACHE}/${BUILD_TIMESTAMP}-build-${BUILD_NUMBER}-${CI_PUBLISH_NAME}-testing_* ${TESTRESULTS_DIR}/
