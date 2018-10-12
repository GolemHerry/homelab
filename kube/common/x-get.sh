#!/bin/bash

set -e

_KUBE_DIR=..

source ${_KUBE_DIR}/env.sh

# kube-proxy is required by controller if you want to run metrics-server
URL_KUBE_PROXY="https://storage.googleapis.com/kubernetes-release/release/v${VER_KUBE}/bin/linux/amd64/kube-proxy"

URL_KUBECTL="https://storage.googleapis.com/kubernetes-release/release/v${VER_KUBE}/bin/linux/amd64/kubectl"

mkdir -p ${DOWNLOAD_DIR}

pushd ${DOWNLOAD_DIR}
wget -q --show-progress --https-only --timestamping \
    "${URL_KUBE_PROXY}" "${URL_KUBECTL}"

cp kubectl kube-proxy ../../controller/${DOWNLOAD_DIR}
cp kubectl kube-proxy ../../worker/${DOWNLOAD_DIR}
popd
