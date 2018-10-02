#!/bin/bash

set -e

COMPONENTS=(envoy grafana)
BUILD_DIR=build

mkdir -p ${BUILD_DIR}
cp -a cert/* ${BUILD_DIR}

for C in ${COMPONENTS[@]}
do
    cp -a ${C}/* ${BUILD_DIR}
    pushd ${BUILD_DIR}
        echo "Building Component: ${C}"
        docker build -q -f ${C}.dockerfile --squash -t homelab-${C}:latest .
        echo "Build Component ${C} Success"
    popd
done
pushd ${BUILD_DIR}
popd

rm -rf ${BUILD_DIR}
