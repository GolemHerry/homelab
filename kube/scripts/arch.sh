#!/usr/bin/env bash

set -e

source scripts/tools.sh

_get_arch_set() {
  local arch_str_list
  local arch_set

  arch_str_list="$($read_conf $1 | cut -d' ' -f2 | paste -sd ' ' -)"
  arch_str_list=($arch_str_list)

  arch_set=($(for v in "${arch_str_list[@]}"; do echo "$v"; done | sort | uniq | xargs))
  echo "${arch_set[@]}"
}

_master_arch_set() {
  _get_arch_set 'cluster.masters.*.arch'
}

_node_arch_set() {
  _get_arch_set 'cluster.nodes.*.arch'
}

_all_arch_set() {
  local arch_str_list
  local arch_set

  arch_str_list="$($read_conf 'cluster.masters.*.arch' | cut -d' ' -f2 | paste -sd ' ' -)"
  arch_str_list="${arch_str_list} $($read_conf 'cluster.nodes.*.arch' | cut -d' ' -f2 | paste -sd ' ' -)"
  arch_str_list=($arch_str_list)

  arch_set=($(for v in "${arch_str_list[@]}"; do echo "$v"; done | sort | uniq | xargs))
  echo "${arch_set[@]}"
}

MASTER_ARCH_LIST=$(_master_arch_set)
NODE_ARCH_LIST=$(_node_arch_set)
ALL_ARCH_LIST=$(_all_arch_set)
