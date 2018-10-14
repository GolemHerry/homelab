#!/bin/bash

set -e

_KUBE_DIR=..

source ${_KUBE_DIR}/env.sh

# generate ca
gen_ca() {
  CERT_CSR_CFG=${GEN_DIR}/csr-ca.json
  cat > ${CERT_CSR_CFG} <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [{
    "C": "${KUBE_CERT_COUNTRY}",
    "L": "${KUBE_CERT_LOCATION}",
    "O": "Kubernetes",
    "OU": "${KUBE_CERT_ORG_UNIT}",
    "ST": "${KUBE_CERT_STATE}"
  }]
}
EOF

  cfssl gencert -initca ${CERT_CSR_CFG} | cfssljson -bare ${GEN_DIR}/ca
  
  AGGREGATOR_CA_CERT_CSR_CFG=${GEN_DIR}/csr-client-ca.json
  cat > ${AGGREGATOR_CA_CERT_CSR_CFG} <<EOF
{
  "CN": "front-proxy-client",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [{
    "C": "${KUBE_CERT_COUNTRY}",
    "L": "${KUBE_CERT_LOCATION}",
    "O": "Kubernetes",
    "OU": "${KUBE_CERT_ORG_UNIT}",
    "ST": "${KUBE_CERT_STATE}"
  }]
}
EOF

  cfssl gencert -initca ${AGGREGATOR_CA_CERT_CSR_CFG} | cfssljson -bare ${GEN_DIR}/ca-aggregator

  # generate cert for aggregator
  cfssl gencert \
    -ca=${GEN_DIR}/ca-aggregator.pem \
    -ca-key=${GEN_DIR}/ca-aggregator-key.pem \
    -config=ca-config.json \
    -profile=kubernetes \
    ${AGGREGATOR_CA_CERT_CSR_CFG} | cfssljson -bare ${GEN_DIR}/aggregator-proxy-client

  rm -f ${CERT_CSR_CFG} ${AGGREGATOR_CA_CERT_CSR_CFG}
}

gen_admin_cert() {
  CERT_CSR_CFG=${GEN_DIR}/csr-admin.json
  cat > ${CERT_CSR_CFG} <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [{
    "C": "${KUBE_CERT_COUNTRY}",
    "L": "${KUBE_CERT_LOCATION}",
    "O": "system:masters",
    "OU": "${KUBE_CERT_ORG_UNIT}",
    "ST": "${KUBE_CERT_STATE}"
  }]
}
EOF

  cfssl gencert \
    -ca=${GEN_DIR}/ca.pem \
    -ca-key=${GEN_DIR}/ca-key.pem \
    -config=ca-config.json \
    -profile=kubernetes \
    ${CERT_CSR_CFG} | cfssljson -bare ${GEN_DIR}/admin
  
  rm -f ${CERT_CSR_CFG}
}

# generate and sign cert for kube admin user
gen_admin_conf() {
  kubectl config set-cluster ${KUBE_CLUSTER_NAME} \
    --certificate-authority=${GEN_DIR}/ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:${KUBE_API_SERVER_PORT} \
    --kubeconfig=${GEN_DIR}/admin.kubeconfig

  kubectl config set-credentials admin \
    --client-certificate=${GEN_DIR}/admin.pem \
    --client-key=${GEN_DIR}/admin-key.pem \
    --embed-certs=true \
    --kubeconfig=${GEN_DIR}/admin.kubeconfig

  kubectl config set-context ${KUBE_CONTEXT_NAME} \
    --cluster=${KUBE_CLUSTER_NAME} \
    --user=admin \
    --kubeconfig=${GEN_DIR}/admin.kubeconfig

  kubectl config use-context ${KUBE_CONTEXT_NAME} \
    --kubeconfig=${GEN_DIR}/admin.kubeconfig
}

gen_kube_porxy_cert() {
  CERT_CSR_CFG=${GEN_DIR}/csr-kube-proxy.json
  cat > ${CERT_CSR_CFG} <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [{
    "C": "${KUBE_CERT_COUNTRY}",
    "L": "${KUBE_CERT_LOCATION}",
    "O": "system:node-proxier",
    "OU": "${KUBE_CERT_ORG_UNIT}",
    "ST": "${KUBE_CERT_STATE}"
  }]
}
EOF

  cfssl gencert \
    -ca=${GEN_DIR}/ca.pem \
    -ca-key=${GEN_DIR}/ca-key.pem \
    -config=ca-config.json \
    -profile=kubernetes \
    ${CERT_CSR_CFG} | cfssljson -bare ${GEN_DIR}/kube-proxy

  rm -f ${CERT_CSR_CFG}
}

gen_kube_proxy_conf() {
  CFG_KUBE_PROXY=${GEN_DIR}/kube-proxy-config.yaml
  cat > ${CFG_KUBE_PROXY} <<EOF
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "${KUBE_PODS_CIDR}"
EOF

  CFG_SYSTEMD_KUBE_PROXY=${GEN_DIR}/kube-proxy.service
  cat > ${CFG_SYSTEMD_KUBE_PROXY} <<EOF
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStartPre=/sbin/modprobe br_netfilter
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  kubectl config set-cluster ${KUBE_CLUSTER_NAME} \
      --certificate-authority=${GEN_DIR}/ca.pem \
      --embed-certs=true \
      --server=https://${HOMELAB_KUBE_PUB_ADDR}:${KUBE_API_SERVER_PORT} \
      --kubeconfig=${GEN_DIR}/kube-proxy.kubeconfig

  kubectl config set-credentials system:kube-proxy \
      --client-certificate=${GEN_DIR}/kube-proxy.pem \
      --client-key=${GEN_DIR}/kube-proxy-key.pem \
      --embed-certs=true \
      --kubeconfig=${GEN_DIR}/kube-proxy.kubeconfig

  kubectl config set-context default \
      --cluster=${KUBE_CLUSTER_NAME} \
      --user=system:kube-proxy \
      --kubeconfig=${GEN_DIR}/kube-proxy.kubeconfig

  kubectl config use-context default \
      --kubeconfig=${GEN_DIR}/kube-proxy.kubeconfig
}

gen_sysctl_conf() {
  CFG_SYSCTL=${GEN_DIR}/kube-sysctl.conf
  cat > ${CFG_SYSCTL} <<EOF
# enable packet forwarding for IPv4
net.ipv4.ip_forward=1
# enable iptables rules to work on Linux bridges
net.bridge.bridge-nf-call-iptables=1
EOF
}

gen_cert() {
  gen_admin_cert
  gen_kube_porxy_cert
}

gen_conf() {
  gen_admin_conf
  gen_kube_proxy_conf
  gen_sysctl_conf
}

mkdir -p ${GEN_DIR}

$@

rm -f ${GEN_DIR}/*.csr
