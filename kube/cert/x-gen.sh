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
    "C": "${CERT_COUNTRY}",
    "L": "${CERT_LOCATION}",
    "O": "Kubernetes",
    "OU": "${CERT_ORG_UNIT}",
    "ST": "${CERT_STATE}"
  }]
}
EOF

  cfssl gencert -initca ${CERT_CSR_CFG} | cfssljson -bare ${GEN_DIR}/ca
  
  rm -f ${CERT_CSR_CFG}
}

# generate and sign cert for kube admin user
gen_admin_conf() {
  CERT_CSR_CFG=${GEN_DIR}/csr-admin.json

  cat > ${CERT_CSR_CFG} <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [{
    "C": "${CERT_COUNTRY}",
    "L": "${CERT_LOCATION}",
    "O": "system:masters",
    "OU": "${CERT_ORG_UNIT}",
    "ST": "${CERT_STATE}"
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

  kubectl config set-cluster ${CLUSTER_NAME} \
    --certificate-authority=${GEN_DIR}/ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:${KUBE_API_SERVER_PORT} \
    --kubeconfig=${GEN_DIR}/admin.kubeconfig

  kubectl config set-credentials admin \
    --client-certificate=${GEN_DIR}/admin.pem \
    --client-key=${GEN_DIR}/admin-key.pem \
    --embed-certs=true \
    --kubeconfig=${GEN_DIR}/admin.kubeconfig

  kubectl config set-context ${CONTEXT_NAME} \
    --cluster=${CLUSTER_NAME} \
    --user=admin \
    --kubeconfig=${GEN_DIR}/admin.kubeconfig

  kubectl config use-context ${CONTEXT_NAME} \
    --kubeconfig=${GEN_DIR}/admin.kubeconfig
}

rm -rf ${GEN_DIR}
mkdir -p ${GEN_DIR}

gen_ca
gen_admin_conf

rm -f ${GEN_DIR}/*.csr
