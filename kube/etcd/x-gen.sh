#!/bin/bash

set -e

_KUBE_DIR=..

source ${_KUBE_DIR}/v-env.sh

rm -rf ${GEN_DIR}
mkdir -p ${GEN_DIR}

# generate
for i in ${!CONTROLLER_LIST[@]}
do
CONTROLLER=${CONTROLLER_LIST[${i}]}
INTERN_IP=${CONTROLLER_INTERN_IP_LIST[${i}]}
ETCD_NAME=etcd-${CONTROLLER}
C_PORT=${KUBE_ETCD_LISTEN_CLIENT_PORT}
P_PORT=${KUBE_ETCD_LISTEN_PEER_PORT}

cat > ${GEN_DIR}/${CONTROLLER}.etcd.service <<EOF
# filename: /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${INTERN_IP}:${P_PORT} \\
  --listen-peer-urls https://${INTERN_IP}:${P_PORT} \\
  --listen-client-urls https://${INTERN_IP}:${C_PORT},https://127.0.0.1:${C_PORT} \\
  --advertise-client-urls https://${INTERN_IP}:${C_PORT} \\
  --initial-cluster-token ${KUBE_ETCD_CLUSTER_NAME} \\
  --initial-cluster ${ETCD_INITIAL_CLUSTERS} \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

done