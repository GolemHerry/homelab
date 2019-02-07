#!/usr/bin/env bash

set -e

source scripts/arch.sh
source scripts/versions.sh

_generate_download_cmd() {
  local kind=$1
  local template=$2
  local version=$3
  local output_template=$4
  local urls=()

  local arch_list=""
  case $kind in
    common)
      arch_list=${ALL_ARCH_LIST}
      ;;
    master)
      arch_list=${MASTER_ARCH_LIST}
      ;;
    node)
      arch_list=${NODE_ARCH_LIST}
      ;;
  esac

  for arch in ${arch_list[@]}; do
    local url=$(eval "echo $template")
    local output=$(eval "echo $output_template")
    local cmd="wget -O $output -q --show-progress --https-only --timestamping $url ;"

    urls+=("$cmd")
  done

  echo "${urls[@]}"
}

# 
# common components
# 
_cmd_download_kube_proxy() {
  local template='https://storage.googleapis.com/kubernetes-release/release/v${version}/bin/linux/${arch}/kube-proxy'
  _generate_download_cmd "common" $template $VER_KUBE 'linux-${arch}.kube-proxy-${version}'
}

_cmd_download_kubectl() {
  local template='https://storage.googleapis.com/kubernetes-release/release/v${version}/bin/linux/${arch}/kubectl'
  _generate_download_cmd "common" $template $VER_KUBE 'linux-${arch}.kubectl-${version}'
}

URL_KUBE_PROXY=$(_cmd_download_kube_proxy)
URL_KUBECTL=$(_cmd_download_kubectl)

# 
# master components
# 
_cmd_download_kube_apiserver() {
  local template='https://storage.googleapis.com/kubernetes-release/release/v${version}/bin/linux/${arch}/kube-apiserver'
  _generate_download_cmd "master" $template $VER_KUBE 'linux-${arch}.kube-apiserver-${version}'
}

_cmd_download_kube_controller_manager() {
  local template='https://storage.googleapis.com/kubernetes-release/release/v${version}/bin/linux/${arch}/kube-controller-manager'
  _generate_download_cmd "master" $template $VER_KUBE 'linux-${arch}.kube-controller-manager-${version}'
}

_cmd_download_kube_scheduler() {
  local template='https://storage.googleapis.com/kubernetes-release/release/v${version}/bin/linux/${arch}/kube-scheduler'
  _generate_download_cmd "master" $template $VER_KUBE 'linux-${arch}.kube-scheduler-${version}'
}

_cmd_download_etcd() {
  local template='https://github.com/coreos/etcd/releases/download/v${version}/etcd-v${version}-linux-${arch}.tar.gz'
  _generate_download_cmd "master" $template $VER_ETCD 'linux-${arch}.etcd-${version}.tar.gz'
}

URL_KUBE_API_SERVER=$(_cmd_download_kube_apiserver)
URL_KUBE_CTRL_MGR=$(_cmd_download_kube_controller_manager)
URL_KUBE_SCHED=$(_cmd_download_kube_scheduler)
URL_ETCD=$(_cmd_download_etcd)

# 
# node components
# 
_cmd_download_crictl() {
  local template='https://github.com/kubernetes-sigs/cri-tools/releases/download/v${version}/crictl-v${version}-linux-${arch}.tar.gz'
  _generate_download_cmd "node" $template $VER_CRICTL 'linux-${arch}.crictl-${version}.tar.gz'
}

_cmd_download_kubelet() {
  local template='https://storage.googleapis.com/kubernetes-release/release/v${version}/bin/linux/${arch}/kubelet'
  _generate_download_cmd "node" $template $VER_KUBE 'linux-${arch}.kubelet-${version}'
}

_cmd_download_runc() {
  local template='https://github.com/opencontainers/runc/releases/download/v${version}/runc.${arch}'
  _generate_download_cmd "node" $template $VER_RUNC 'linux-${arch}.runc-${version}'
}

_cmd_download_runsc() {
  local template='https://storage.googleapis.com/gvisor/releases/nightly/${version}/runsc'
  _generate_download_cmd "node" $template $VER_RUNSC 'linux-${arch}.runsc-${version}'
}

_cmd_download_containerd() {
  local template='https://github.com/containerd/containerd/releases/download/v${version}/containerd-${version}.linux-${arch}.tar.gz'
  _generate_download_cmd "node" $template $VER_CONTAINERD 'linux-${arch}.containerd-${version}.tar.gz'
}

_cmd_download_cni_plugins() {
  local template='https://github.com/containernetworking/plugins/releases/download/v${version}/cni-plugins-${arch}-v${version}.tgz'
  _generate_download_cmd "node" $template $VER_CNI_PLUGINS 'linux-${arch}.cni-plugins-${version}.tgz'
}

URL_CRICTL=$(_cmd_download_crictl)
URL_KUBELET=$(_cmd_download_kubelet)
URL_RUNC=$(_cmd_download_runc)
URL_RUNSC=$(_cmd_download_runsc)
URL_CONTAINERD=$(_cmd_download_containerd)
URL_CNI_PLGUINS=$(_cmd_download_cni_plugins)
