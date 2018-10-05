#!/bin/bash -x

set -e

_KUBE_DIR=..

source ${_KUBE_DIR}/env.sh

URL_KUBE_API_SERVER="https://storage.googleapis.com/kubernetes-release/release/v${VER_KUBE}/bin/linux/amd64/kube-apiserver"

URL_KUBE_CTRL_MGR="https://storage.googleapis.com/kubernetes-release/release/v${VER_KUBE}/bin/linux/amd64/${COMP_KUBE_CTRL_MGR}"

URL_KUBE_SCHEDULER="https://storage.googleapis.com/kubernetes-release/release/v${VER_KUBE}/bin/linux/amd64/kube-scheduler"

URL_KUBECTL="https://storage.googleapis.com/kubernetes-release/release/v${VER_KUBE}/bin/linux/amd64/kubectl"

ETCD_FILE="etcd-v${VER_ETCD}-linux-amd64.tar.gz"
URL_ETCD="https://github.com/coreos/etcd/releases/download/v${VER_ETCD}/${ETCD_FILE}"

mkdir -p ${DOWNLOAD_DIR}

pushd ${DOWNLOAD_DIR}
wget -q --show-progress --https-only --timestamping \
    "${URL_KUBE_API_SERVER}" "${URL_KUBE_CTRL_MGR}" \
    "${URL_KUBE_SCHEDULER}" "${URL_KUBECTL}" "${URL_ETCD}"
popd
