#!/bin/bash

set -e

TARGETS=(controller worker etcd)
for T in ${TARGETS[@]}
do
  pushd ${T}
    ./x-get.sh
  popd
done
