#!/bin/bash

set -e

_KUBE_DIR=..

source ${_KUBE_DIR}/env.sh

URL_CRICTL="https://github.com/kubernetes-sigs/cri-tools/releases/download/v${VER_KUBE}/crictl-v${VER_KUBE}-linux-amd64.tar.gz"

URL_KUBE_PROXY="https://storage.googleapis.com/kubernetes-release/release/v${VER_KUBE}/bin/linux/amd64/kube-proxy"

URL_KUBELET="https://storage.googleapis.com/kubernetes-release/release/v${VER_KUBE}/bin/linux/amd64/kubelet"

URL_KUBECTL="https://storage.googleapis.com/kubernetes-release/release/v${VER_KUBE}/bin/linux/amd64/kubectl"

URL_RUNC="https://github.com/opencontainers/runc/releases/download/v${VER_RUNC}/runc.amd64"

URL_RUNSC="https://storage.googleapis.com/kubernetes-the-hard-way/runsc-50c283b9f56bb7200938d9e207355f05f79f0d17"

URL_CONTAINERD="https://github.com/containerd/containerd/releases/download/v${VER_CONTAINERD}/containerd-${VER_CONTAINERD}.linux-amd64.tar.gz"

URL_CNI_PLUGINS="https://github.com/containernetworking/plugins/releases/download/v${VER_CNI_PLUGINS}/cni-plugins-amd64-v${VER_CNI_PLUGINS}.tgz"

mkdir -p ${DOWNLOAD_DIR}

pushd ${DOWNLOAD_DIR}
wget -q --show-progress --https-only --timestamping \
  "${URL_CRICTL}" "${URL_KUBE_PROXY}" "${URL_KUBELET}" \
  "${URL_RUNC}" "${URL_RUNSC}" "${URL_CONTAINERD}" \
  "${URL_CNI_PLUGINS}" "${URL_KUBECTL}"
popd
