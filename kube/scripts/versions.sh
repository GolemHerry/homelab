#!/usr/bin/env bash

set -e

source scripts/tools.sh

VER_KUBE="$($read_conf 'cluster.versions.kubernetes')"
VER_ETCD="$($read_conf 'cluster.versions.etcd')"
VER_CRICTL="$($read_conf 'cluster.versions.crictl')"
VER_RUNC="$($read_conf 'cluster.versions.runc')"
VER_RUNSC="$($read_conf 'cluster.versions.runsc')"
VER_CONTAINERD="$($read_conf 'cluster.versions.containerd')"
VER_CNI_SPEC="$($read_conf 'cluster.versions.cni.spec')"
VER_CNI_PLUGINS="$($read_conf 'cluster.versions.cni.plugins')"
