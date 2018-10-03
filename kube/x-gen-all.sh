#!/bin/bash

set -e

TARGETS=(cert controller worker etcd)
for T in ${TARGETS[@]}
do
  pushd ${T}
    ./x-gen.sh
  popd
done
