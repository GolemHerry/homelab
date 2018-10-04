#!/bin/bash

set -e

_KUBE_DIR=..

source ${_KUBE_DIR}/env.sh

mkdir -p ${DOWNLOAD_DIR}

FILE="etcd-v${VER_ETCD}-linux-amd64.tar.gz"
URL="https://github.com/coreos/etcd/releases/download/v${VER_ETCD}/${FILE}"

pushd ${DOWNLOAD_DIR}
wget -q --show-progress --https-only --timestamping "${URL}"
popd
