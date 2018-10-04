#!/bin/bash

set -e

_KUBE_DIR=..
source ${_KUBE_DIR}/env.sh

CA_DIR=${_KUBE_DIR}/cert
CA_GEN_DIR=${_KUBE_DIR}/cert/${GEN_DIR}

gen_kube_proxy_conf() {
  CERT_CSR_CFG=${GEN_DIR}/csr-${COMP_KUBE_PROXY}.json
  cat > ${CERT_CSR_CFG} <<EOF
{
  "CN": "system:${COMP_KUBE_PROXY}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [{
    "C": "${CERT_COUNTRY}",
    "L": "${CERT_LOCATION}",
    "O": "system:node-proxier",
    "OU": "${CERT_ORG_UNIT}",
    "ST": "${CERT_STATE}"
  }]
}
EOF

  cfssl gencert \
    -ca=${CA_GEN_DIR}/ca.pem \
    -ca-key=${CA_GEN_DIR}/ca-key.pem \
    -config=${CA_DIR}/ca-config.json \
    -profile=kubernetes \
    ${CERT_CSR_CFG} | cfssljson -bare ${GEN_DIR}/${COMP_KUBE_PROXY}

  rm -f ${CERT_CSR_CFG}

  kubectl config set-cluster ${CLUSTER_NAME} \
      --certificate-authority=${CA_GEN_DIR}/ca.pem \
      --embed-certs=true \
      --server=https://${KUBE_PUB_ADDR}:${KUBE_API_SERVER_PORT} \
      --kubeconfig=${GEN_DIR}/${COMP_KUBE_PROXY}.kubeconfig

  kubectl config set-credentials system:${COMP_KUBE_PROXY} \
      --client-certificate=${GEN_DIR}/${COMP_KUBE_PROXY}.pem \
      --client-key=${GEN_DIR}/${COMP_KUBE_PROXY}-key.pem \
      --embed-certs=true \
      --kubeconfig=${GEN_DIR}/${COMP_KUBE_PROXY}.kubeconfig

  kubectl config set-context default \
      --cluster=${CLUSTER_NAME} \
      --user=system:${COMP_KUBE_PROXY} \
      --kubeconfig=${GEN_DIR}/${COMP_KUBE_PROXY}.kubeconfig

  kubectl config use-context default \
      --kubeconfig=${GEN_DIR}/${COMP_KUBE_PROXY}.kubeconfig
}

gen_kubelet_conf() {
  # Kubernetes uses a special-purpose authorization mode called Node Authorizer, 
  # that specifically authorizes API requests made by Kubelets. 
  # In order to be authorized by the Node Authorizer, 
  # Kubelets must use a credential that identifies them as being in the system:nodes group, 
  # with a username of system:node:<nodeName>

  for i in ${!WORKER_LIST[@]}
  do

  WORKER=${WORKER_LIST[${i}]}
  INTERN_IP=${WORKER_INTERN_IP_LIST[${i}]}
  EXTERN_IP=${WORKER_EXTERN_IP_LIST[${i}]}

  CERT_CSR_CFG=${GEN_DIR}/csr-${WORKER}.json

  cat > ${CERT_CSR_CFG} <<EOF
{
  "CN": "system:node:${WORKER}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [{
    "C": "${CERT_COUNTRY}",
    "L": "${CERT_LOCATION}",
    "O": "system:nodes",
    "OU": "${CERT_ORG_UNIT}",
    "ST": "${CERT_STATE}"
  }]
}
EOF

  cfssl gencert \
    -ca=${CA_GEN_DIR}/ca.pem \
    -ca-key=${CA_GEN_DIR}/ca-key.pem \
    -config=${CA_DIR}/ca-config.json \
    -hostname=${WORKER},${EXTERN_IP},${INTERN_IP} \
    -profile=kubernetes \
    ${CERT_CSR_CFG} | cfssljson -bare ${GEN_DIR}/${WORKER}

  rm -f ${CERT_CSR_CFG}

  # generate kubelet kubeconfig
  kubectl config set-cluster ${CLUSTER_NAME} \
      --certificate-authority=${CA_GEN_DIR}/ca.pem \
      --embed-certs=true \
      --server=https://${KUBE_PUB_ADDR}:${KUBE_API_SERVER_PORT} \
      --kubeconfig=${GEN_DIR}/${WORKER}.kubeconfig

  kubectl config set-credentials system:node:${WORKER} \
      --client-certificate=${GEN_DIR}/${WORKER}.pem \
      --client-key=${GEN_DIR}/${WORKER}-key.pem \
      --embed-certs=true \
      --kubeconfig=${GEN_DIR}/${WORKER}.kubeconfig

  kubectl config set-context ${CONTEXT_NAME} \
      --cluster=${CLUSTER_NAME} \
      --user=system:node:${WORKER} \
      --kubeconfig=${GEN_DIR}/${WORKER}.kubeconfig

  kubectl config use-context ${CONTEXT_NAME} \
      --kubeconfig=${GEN_DIR}/${WORKER}.kubeconfig
  done
}

rm -rf ${GEN_DIR}
mkdir -p ${GEN_DIR}

gen_kube_proxy_conf
gen_kubelet_conf

rm -f ${GEN_DIR}/*.csr