#!/usr/bin/env bash

set -e

read_conf="yq r -d0 cluster.config.yaml"

download_components() {
  mkdir -p download

  pushd download
    local command_list=(
      # common components
      "${URL_KUBE_PROXY}"
      "${URL_KUBECTL}"
      # master components
      "${URL_KUBE_API_SERVER}"
      "${URL_KUBE_CTRL_MGR}"
      "${URL_KUBE_SCHED}"
      "${URL_ETCD}"
      # node components
      "${URL_CRICTL}"
      "${URL_KUBELET}"
      "${URL_RUNC}"
      "${URL_RUNSC}"
      "${URL_CONTAINERD}"
      "${URL_CNI_PLGUINS}"
    )

    for cmd in "${command_list[@]}"; do
      eval "${cmd}"
    done
  popd
}

remote_exec() {
  local target_host=$1

  local cmd=$2
  local port=$(echo "${target_host}" | yq r - 'ssh.port')
  local identity=$(echo "${target_host}" | yq r - 'ssh.identity')
  local user=$(echo "${target_host}" | yq r - 'ssh.user')
  local password=$(echo "${target_host}" | yq r - 'ssh.sudo_password')
  local address=$(echo "${target_host}" | yq r - 'network[0].public_address')

  eval "ssh -i ${identity} -p ${port} ${user}@${address} echo ${password} | sudo -S $cmd"
}

remote_cp() {
  local target_host=$1

  local local_file=$2
  local remote_file=$3
  local port=$(echo "${target_host}" | yq r - 'ssh.port')
  local user=$(echo "${target_host}" | yq r - 'ssh.user')
  local identity=$(echo "${target_host}" | yq r - 'ssh.identity')
  local address=$(echo "${target_host}" | yq r - 'network[0].public_address')

  eval "scp -P ${port} -i ${identity} ${local_file} ${user}@${address}:${remote_file}"
}

upload_bin() {
  local kind=$1
  local target_host=$2

  local hostname=$(echo "${target_host}" | yq r - 'hostname')

  local bin_prefix="linux-$(echo "${target_host}" | yq r - 'arch')"
  echo $hostname

  local bin_list=(
    "${bin_prefix}.kubelet-${VER_KUBE}"
    "${bin_prefix}.kube-proxy-${VER_KUBE}"
    "${bin_prefix}.kubectl-${VER_KUBE}"
  )

  case $kind in
    master)
      bin_list+=(
        "${bin_prefix}.kube-apiserver-${VER_KUBE}"
        "${bin_prefix}.kube-controller-manager-${VER_KUBE}"
        "${bin_prefix}.kube-scheduler-${VER_KUBE}"
        "${bin_prefix}.etcd-${VER_ETCD}.tar.gz"
      )
      ;;
    node)
      bin_list+=(
        "${bin_prefix}.runc-${VER_RUNC}"
        "${bin_prefix}.runsc-${VER_RUNSC}"
        "${bin_prefix}.containerd-${VER_CONTAINERD}.tar.gz"
        "${bin_prefix}.cni-plugins-${VER_CNI_PLUGINS}.tgz"
        "${bin_prefix}.crictl-${VER_CRICTL}.tar.gz"
      )
      ;;
  esac

  mkdir -p generated
  pushd generated
    local comp_to_upload="${kind}-comp-${hostname}.tar.xz"
    if [[ ! -f "${comp_to_upload}" ]]; then
      local bin_included=()
      for b in "${bin_list[@]}"; do
        bin_included+=("../download/${b}")
      done
      tar Jcf "${comp_to_upload}" "${bin_included[@]}"
    fi

    remote_cp "${target_host}" "${comp_to_upload}" '~/'
  popd
}

upload_master_bin_all() {
  local masters="$($read_conf 'cluster.masters[*].hostname' | cut -d' ' -f2 | paste -sd ' ' -)"
  masters=($masters)

  for i in "${!masters[@]}"; do
    local master=$($read_conf "cluster.masters[${i}]")
    upload_bin "master" "$master"
  done
}

upload_node_bin_all() {
  local nodes="$($read_conf 'cluster.nodes[*].hostname' | cut -d' ' -f2 | paste -sd ' ' -)"
  nodes=($nodes)

  for i in "${!nodes[@]}"; do
    local node="$($read_conf "cluster.nodes[${i}]")"
    upload_bin "node" "$node"
  done
}

upload_bin_all() {
  upload_master_bin_all
  upload_node_bin_all
}
