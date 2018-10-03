#!/bin/bash

set -e

_KUBE_DIR=..

source ${_KUBE_DIR}/v-env.sh

CA_DIR=${_KUBE_DIR}/cert
CA_GEN_DIR=${_KUBE_DIR}/cert/${GEN_DIR}

rm -rf ${GEN_DIR}
mkdir -p ${GEN_DIR}

gen_common() {
  TARGET=(${COMP_KUBE_CTRL_MGR} ${COMP_KUBE_SCHEDULER})
  for T in ${TARGET[@]}
  do
    CERT_CSR_CFG=${GEN_DIR}/csr-${T}.json
    
    cat > ${CERT_CSR_CFG} <<EOF
{
  "CN": "system:${T}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [{
    "C": "${CERT_COUNTRY}",
    "L": "${CERT_LOCATION}",
    "O": "system:${T}",
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
      ${CERT_CSR_CFG} | cfssljson -bare ${GEN_DIR}/${T}

    kubectl config set-cluster ${CLUSTER_NAME} \
      --certificate-authority=${CA_GEN_DIR}/ca.pem \
      --embed-certs=true \
      --server=https://127.0.0.1:${KUBE_API_SERVER_PORT} \
      --kubeconfig=${GEN_DIR}/${T}.kubeconfig

    kubectl config set-credentials system:${T} \
      --client-certificate=${GEN_DIR}/${T}.pem \
      --client-key=${GEN_DIR}/${T}-key.pem \
      --embed-certs=true \
      --kubeconfig=${GEN_DIR}/${T}.kubeconfig

    kubectl config set-context ${CONTEXT_NAME} \
      --cluster=${CLUSTER_NAME} \
      --user=system:${T} \
      --kubeconfig=${GEN_DIR}/${T}.kubeconfig

    kubectl config use-context ${CONTEXT_NAME} \
      --kubeconfig=${GEN_DIR}/${T}.kubeconfig

    rm -f ${CERT_CSR_CFG}
  done

  rm -f ${GEN_DIR}/*.csr
}

gen_kube_controller_manager_conf() {

  cat > ${GEN_DIR}/${COMP_KUBE_CTRL_MGR}.service <<EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/${COMP_KUBE_CTRL_MGR} \\
  --bind-address=0.0.0.0 \\
  --cluster-cidr=${KUBE_CLUSTER_CIDR} \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/${COMP_KUBE_CTRL_MGR}.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=${KUBE_SERVICE_IP_RANGE} \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

}

gen_kube_scheduler_conf() {

  cat > ${GEN_DIR}/${COMP_KUBE_SCHEDULER}.yaml <<EOF
apiVersion: componentconfig/v1alpha1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/${COMP_KUBE_SCHEDULER}.kubeconfig"
leaderElection:
  leaderElect: true
EOF

  cat > ${GEN_DIR}/${COMP_KUBE_SCHEDULER}.service <<EOF
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/${COMP_KUBE_SCHEDULER} \\
  --config=/etc/kubernetes/config/${COMP_KUBE_SCHEDULER}.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

}

gen_kube_service_account_conf() {
  CERT_CSR_CFG=${GEN_DIR}/csr-${COMP_KUBE_SERVICE_ACCOUNT}.json

  cat > ${CERT_CSR_CFG} <<EOF
{
  "CN": "${COMP_KUBE_SERVICE_ACCOUNT}s",
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

  cfssl gencert \
    -ca=${CA_GEN_DIR}/ca.pem \
    -ca-key=${CA_GEN_DIR}/ca-key.pem \
    -config=${CA_DIR}/ca-config.json \
    -profile=kubernetes \
    ${CERT_CSR_CFG} | cfssljson -bare ${GEN_DIR}/${COMP_KUBE_SERVICE_ACCOUNT}
  
  rm -f ${CERT_CSR_CFG}

  kubectl config set-cluster ${CLUSTER_NAME} \
    --certificate-authority=${CA_GEN_DIR}/ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:${KUBE_API_SERVER_PORT} \
    --kubeconfig=${GEN_DIR}/${COMP_KUBE_SERVICE_ACCOUNT}.kubeconfig

  kubectl config set-credentials system:${COMP_KUBE_SERVICE_ACCOUNT} \
    --client-certificate=${GEN_DIR}/${COMP_KUBE_SERVICE_ACCOUNT}.pem \
    --client-key=${GEN_DIR}/${COMP_KUBE_SERVICE_ACCOUNT}-key.pem \
    --embed-certs=true \
    --kubeconfig=${GEN_DIR}/${COMP_KUBE_SERVICE_ACCOUNT}.kubeconfig

  kubectl config set-context ${CONTEXT_NAME} \
    --cluster=${CLUSTER_NAME} \
    --user=system:${COMP_KUBE_SERVICE_ACCOUNT} \
    --kubeconfig=${GEN_DIR}/${COMP_KUBE_SERVICE_ACCOUNT}.kubeconfig

  kubectl config use-context ${CONTEXT_NAME} \
    --kubeconfig=${GEN_DIR}/${COMP_KUBE_SERVICE_ACCOUNT}.kubeconfig
}

gen_encryption_key() {
  ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

  cat > ${GEN_DIR}/encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
}

gen_common
gen_kube_controller_manager_conf
gen_kube_scheduler_conf
gen_kube_service_account_conf
gen_encryption_key