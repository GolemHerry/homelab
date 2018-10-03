#!/bin/bash

set -e

source ../v-env.sh

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

# generate 
gen_kube_apiserver_conf() {
  CERT_CSR_CFG=${GEN_DIR}/${COMP_KUBE_API_SERVER}.json
  cat > ${CERT_CSR_CFG} <<EOF
{
  "CN": "${COMP_KUBE_API_SERVER}",
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
    -ca=${GEN_DIR}/ca.pem \
    -ca-key=${GEN_DIR}/ca-key.pem \
    -config=ca-config.json \
    -hostname=${WORKER_ADDR_LIST},${KUBE_PUB_ADDR},127.0.0.1,kubernetes.default \
    -profile=kubernetes \
    ${CERT_CSR_CFG} | cfssljson -bare ${GEN_DIR}/${COMP_KUBE_API_SERVER}

  rm -f ${CERT_CSR_CFG}

  cat > ${GEN_DIR}/${COMP_KUBE_API_SERVER}.service <<EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=Initializers,NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --enable-swagger-ui=true \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=${ETCD_INITIAL_CLUSTERS} \\
  --event-ttl=1h \\
  --experimental-encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --kubelet-https=true \\
  --runtime-config=api/all \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-cluster-ip-range=${KUBE_SERVICE_IP_RANGE} \\
  --service-node-port-range=${KUBE_SERVICE_PORT_RANGE} \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
}

rm -rf ${GEN_DIR}
mkdir -p ${GEN_DIR}

gen_ca
gen_admin_conf
gen_kube_apiserver_conf

rm -f ${GEN_DIR}/*.csr
