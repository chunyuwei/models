#!/usr/bin/env bash

# Copyright (c) 2021 PaddlePaddle Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#=================================================
#                   Utils
#=================================================


# directory config
DIST_DIR="dist"
BUILD_DIR="build"
EGG_DIR="paddlecv.egg-info"

CFG_DIR="configs"
TEST_DIR="unittests"
DATA_DIR="demo"

# command line log config
RED='\033[0;31m'
BLUE='\033[0;34m'
GREEN='\033[1;32m'
BOLD='\033[1m'
NONE='\033[0m'

function python_version_check() {
  PY_MAIN_VERSION=`python -V 2>&1 | awk '{print $2}' | awk -F '.' '{print $1}'`
  PY_SUB_VERSION=`python -V 2>&1 | awk '{print $2}' | awk -F '.' '{print $2}'`
  echo -e "find python version ${PY_MAIN_VERSION}.${PY_SUB_VERSION}"
  if [ $PY_MAIN_VERSION -ne "3" -o $PY_SUB_VERSION -lt "5" ]; then
    echo -e "${RED}FAIL:${NONE} please use Python >= 3.5 !"
    exit 1
  fi
}

function init() {
    echo -e "${BLUE}[init]${NONE} removing building directory..."
    rm -rf $DIST_DIR $BUILD_DIR $EGG_DIR $TEST_DIR
    if [ `pip list | grep paddlecv | wc -l` -gt 0  ]; then
      echo -e "${BLUE}[init]${NONE} uninstalling paddlecv..."
      pip uninstall -y paddlecv
    fi
    echo -e "${BLUE}[init]${NONE} ${GREEN}init success\n"
}

function build_and_install() {
  echo -e "${BLUE}[build]${NONE} building paddlecv wheel..."
  python setup.py sdist bdist_wheel
  if [ $? -ne 0 ]; then
    echo -e "${RED}[FAIL]${NONE} build paddlecv wheel failed !"
    exit 1
  fi
  echo -e "${BLUE}[build]${NONE} ${GREEN}build paddlecv wheel success\n"

  echo -e "${BLUE}[install]${NONE} installing paddlecv..."
  cd $DIST_DIR
  find . -name "paddlecv*.whl" | xargs pip install
  if [ $? -ne 0 ]; then
    cd ..
    echo -e "${RED}[FAIL]${NONE} install paddlecv wheel failed !"
    exit 1
  fi
  echo -e "${BLUE}[install]${NONE} ${GREEN}paddlecv install success\n"
  cd ..
}

function unittest() {
  if [ -d $TEST_DIR ]; then
    rm -rf $TEST_DIR
  fi;

  echo -e "${BLUE}[unittest]${NONE} run unittests..."

  # NOTE: perform unittests under TEST_DIR to
  #       make sure installed paddlecv is used
  mkdir $TEST_DIR
  cp -r $CFG_DIR $TEST_DIR
  cp -r $DATA_DIR $TEST_DIR
  cd $TEST_DIR
  if [ $? != 0  ]; then
    exit 1
  fi
  find "../" -wholename '*tests/test_*' -type f -print0 | \
      xargs -0 -I{} -n1 -t bash -c  'python -u -s {}'

  # clean TEST_DIR
  cd ..
  rm -rf $TEST_DIR
  echo -e "${BLUE}[unittest]${NONE} ${GREEN}unittests success\n${NONE}"
}

function cleanup() {
  if [ -d $TEST_DIR ]; then
    rm -rf $TEST_DIR
  fi

  rm -rf $BUILD_DIR $EGG_DIR
  pip uninstall -y paddlecv
}

function abort() {
  echo -e "${RED}[FAIL]${NONE} build wheel and unittest failed !
          please check your code" 1>&2

  cur_dir=`basename "$pwd"`
  if [ cur_dir==$TEST_DIR -o cur_dir==$DIST_DIR ]; then
    cd ..
  fi

  rm -rf $BUILD_DIR $EGG_DIR $DIST_DIR $TEST_DIR
  pip uninstall -y paddlecv
}

python_version_check

trap 'abort' 0
set -e

init
build_and_install
unittest
cleanup

# get Paddle version
PADDLE_VERSION=`python -c "import paddle; print(paddle.version.full_version)"`
PADDLE_COMMIT=`python -c "import paddle; print(paddle.version.commit)"`
PADDLE_COMMIT=`git rev-parse --short $PADDLE_COMMIT`

# get PaddleDetection branch
PPCV_BRANCH=`git rev-parse --abbrev-ref HEAD`
PPCV_COMMIT=`git rev-parse --short HEAD`

# get Python version
PYTHON_VERSION=`python -c "import platform; print(platform.python_version())"`

echo -e "\n${GREEN}paddlecv wheel compiled and checked success !${NONE}
        ${BLUE}Python version:${NONE} $PYTHON_VERSION
        ${BLUE}Paddle version:${NONE} $PADDLE_VERSION ($PADDLE_COMMIT)
        ${BLUE}PaddleCV  branch:${NONE} $PPCV_BRANCH ($PPCV_COMMIT)\n"

echo -e "${GREEN}wheel saved under${NONE} ${RED}${BOLD}./dist"

trap : 0
