#!/bin/bash

set -e

_KUBE_DIR=..

source ${_KUBE_DIR}/env.sh

CA_DIR=${_KUBE_DIR}/common
CA_GEN_DIR=${_KUBE_DIR}/common/${GEN_DIR}

gen_etcd_conf() {
  for i in ${!CTRL_LIST[@]}
  do
    CTRL=${CTRL_LIST[${i}]}
    INTERN_IP=${CTRL_INTERN_IP_LIST[${i}]}
    ETCD_NAME=etcd-${CTRL}
    C_PORT=${KUBE_ETCD_LISTEN_CLIENT_PORT}
    P_PORT=${KUBE_ETCD_LISTEN_PEER_PORT}

    cat > ${GEN_DIR}/${CTRL}.etcd.service <<EOF
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
Type=notify

[Install]
WantedBy=multi-user.target
EOF
  done
}

gen_common_cert() {
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

    rm -f ${CERT_CSR_CFG}
  done
}

gen_common_conf() {
  TARGET=(${COMP_KUBE_CTRL_MGR} ${COMP_KUBE_SCHEDULER})
  for T in ${TARGET[@]}
  do
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
  done
}

gen_kube_apiserver_cert() {
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
    -ca=${CA_GEN_DIR}/ca.pem \
    -ca-key=${CA_GEN_DIR}/ca-key.pem \
    -config=${CA_DIR}/ca-config.json \
    -hostname=${WORKER_ADDR_LIST},${CTRL_ADDR_LIST},${KUBE_PUB_ADDR},${KUBE_SERVICE_CLUSTER_GW_ADDR},127.0.0.1,kubernetes.default \
    -profile=kubernetes \
    ${CERT_CSR_CFG} | cfssljson -bare ${GEN_DIR}/${COMP_KUBE_API_SERVER}

  rm -f ${CERT_CSR_CFG}
}

gen_kube_apiserver_conf() {
  for i in ${!CTRL_LIST[@]}
  do
    CTRL=${CTRL_LIST[${i}]}
    INTERN_IP=${CTRL_INTERN_IP_LIST[${i}]}
    cat > ${GEN_DIR}/${CTRL}-kube-apiserver.service <<EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${INTERN_IP} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/${COMP_KUBE_API_SERVER}/ca.pem \\
  --requestheader-client-ca-file=/var/lib/${COMP_KUBE_API_SERVER}/ca-aggregator.pem \\
  --proxy-client-cert-file=/var/lib/${COMP_KUBE_API_SERVER}/aggregator-proxy-client.pem \\
  --proxy-client-key-file=/var/lib/${COMP_KUBE_API_SERVER}/aggregator-proxy-client-key.pem \\
  --requestheader-allowed-names= \\
  --requestheader-extra-headers-prefix=X-Remote-Extra- \\
  --requestheader-group-headers=X-Remote-Group \\
  --requestheader-username-headers=X-Remote-User \\
  --enable-admission-plugins=Initializers,NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --enable-swagger-ui=true \\
  --etcd-cafile=/var/lib/${COMP_KUBE_API_SERVER}/ca.pem \\
  --etcd-certfile=/var/lib/${COMP_KUBE_API_SERVER}/${COMP_KUBE_API_SERVER}.pem \\
  --etcd-keyfile=/var/lib/${COMP_KUBE_API_SERVER}/${COMP_KUBE_API_SERVER}-key.pem \\
  --etcd-servers=${ETCD_SERVERS} \\
  --event-ttl=1h \\
  --kubelet-certificate-authority=/var/lib/${COMP_KUBE_API_SERVER}/ca.pem \\
  --kubelet-client-certificate=/var/lib/${COMP_KUBE_API_SERVER}/${COMP_KUBE_API_SERVER}.pem \\
  --kubelet-client-key=/var/lib/${COMP_KUBE_API_SERVER}/${COMP_KUBE_API_SERVER}-key.pem \\
  --kubelet-https=true \\
  --runtime-config=api/all \\
  --service-account-key-file=/var/lib/${COMP_KUBE_API_SERVER}/${COMP_KUBE_SERVICE_ACCOUNT}.pem \\
  --service-cluster-ip-range=${KUBE_SERVICE_IP_RANGE} \\
  --service-node-port-range=${KUBE_NODE_PORT_RANGE} \\
  --tls-cert-file=/var/lib/${COMP_KUBE_API_SERVER}/${COMP_KUBE_API_SERVER}.pem \\
  --tls-private-key-file=/var/lib/${COMP_KUBE_API_SERVER}/${COMP_KUBE_API_SERVER}-key.pem \\
  --v=2

# 
# currently, we will disable encryption, see https://github.com/kubernetes/kubernetes/issues/66844
# 
# --experimental-encryption-provider-config=/var/lib/${COMP_KUBE_API_SERVER}/encryption-config.yaml

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  done
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
  --service-account-private-key-file=/var/lib/kubernetes/${COMP_KUBE_SERVICE_ACCOUNT}-key.pem \\
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

gen_kube_service_account_cert() {
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
}

gen_kube_service_account_conf() {
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
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF
}

gen_deploy_script() {
  cat > ${GEN_DIR}/RBAC-create.yaml <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF

  cat > ${GEN_DIR}/RBAC-bind.yaml <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF

  CFG_HEALTH_CHECK=${GEN_DIR}/healthcheck.nginx
  cat > ${CFG_HEALTH_CHECK} <<EOF
server {
  listen      80;
  server_name kubernetes.default.svc.cluster.local;

  location /healthz {
     proxy_pass                    https://127.0.0.1:${KUBE_API_SERVER_PORT}/healthz;
     proxy_ssl_trusted_certificate /var/lib/kubernetes/ca.pem;
  }
}
EOF

  for i in ${!CTRL_LIST[@]}
  do
    CTRL=${CTRL_LIST[${i}]}

    INTERN_IP=${CTRL_INTERN_IP_LIST[${i}]}
    IFACE=${CTRL_NET_IFACE_LIST[${i}]}

    CFG_NET_ROUTE=""
      for j in ${!WORKER_LIST[@]}
      do
        W_POD_CIDR=${WORKER_POD_CIDR_LIST[${j}]}
        W_INTERN_IP=${WORKER_INTERN_IP_LIST[${j}]}
        CFG_NET_ROUTE=$(cat <<EOF
      - to: ${W_POD_CIDR}
        via: ${W_INTERN_IP}
${CFG_NET_ROUTE}
EOF
)
  done

  CFG_NETWORK=${GEN_DIR}/${CTRL}-network.yaml
  cat > ${CFG_NETWORK} <<EOF
network:
  ethernets:
    ${IFACE}:
      addresses:
      - ${INTERN_IP}/${HOMELAB_NET_PREFIX_LEN}
      dhcp4: no
      dhcp6: no
      gateway4: ${HOMELAB_GW_IPV4}
      nameservers:
        addresses:
        - ${HOMELAB_DNS_SRV}
        search: []
      routes:
${CFG_NET_ROUTE}
  version: 2
EOF

    SCRIPT=${GEN_DIR}/${CTRL}-deploy.sh
    cat > ${SCRIPT} <<EOF
#!/bin/bash
set -e

mkdir -p \\
  /etc/${COMP_KUBE_API_SERVER}/config \\
  /var/lib/${COMP_KUBE_API_SERVER}/ \\
  /var/lib/kube-proxy \\
  /etc/etcd

install_cert() {
  # copy certs required by etcd
  cp ca.pem ${COMP_KUBE_API_SERVER}*.pem /etc/etcd/
  
  # Install certs
  mv ca*.pem \\
    ${COMP_KUBE_API_SERVER}*.pem \\
    ${COMP_KUBE_SERVICE_ACCOUNT}*.pem \\
    aggregator-proxy-client*.pem \\
    encryption-config.yaml \\
    /var/lib/${COMP_KUBE_API_SERVER}/
}

install_conf() {
  # Install Systemd Configurations
  mv ${CTRL}-kube-apiserver.service /etc/systemd/system/kube-apiserver.service
  mv ${COMP_KUBE_CTRL_MGR}.service /etc/systemd/system/${COMP_KUBE_CTRL_MGR}.service
  mv ${COMP_KUBE_SCHEDULER}.service /etc/systemd/system/${COMP_KUBE_SCHEDULER}.service
  mv ${CTRL}.etcd.service /etc/systemd/system/etcd.service

  # Install Kube Configurations
  mv ${COMP_KUBE_SCHEDULER}.kubeconfig /var/lib/${COMP_KUBE_API_SERVER}/${COMP_KUBE_SCHEDULER}.kubeconfig
  mv ${COMP_KUBE_SCHEDULER}.yaml /etc/${COMP_KUBE_API_SERVER}/config/${COMP_KUBE_SCHEDULER}.yaml
  mv ${COMP_KUBE_CTRL_MGR}.kubeconfig /var/lib/${COMP_KUBE_API_SERVER}/${COMP_KUBE_CTRL_MGR}.kubeconfig

  # Install configurations for kube-proxy
  mv kube-proxy-config.yaml /var/lib/kube-proxy/kube-proxy-config.yaml
  mv kube-proxy.service /etc/systemd/system/kube-proxy.service
  mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig

  # Setup Health Check
  mv healthcheck.nginx /etc/nginx/sites-available/kubernetes.default.svc.cluster.local
  rm -f /etc/nginx/sites-enabled/kubernetes.default.svc.cluster.local
  ln -s /etc/nginx/sites-available/kubernetes.default.svc.cluster.local /etc/nginx/sites-enabled/
  
  # Install configurations for network
  mv ${CTRL}-network.yaml /etc/netplan/50-cloud-init.yaml
  mv kube-sysctl.conf /etc/sysctl.d/10-kube-sysctl.conf
}

apply_rbac() {
  # Enable RBAC Auth
  kubectl apply --kubeconfig ~/admin.kubeconfig -f ~/RBAC-create.yaml
  kubectl apply --kubeconfig ~/admin.kubeconfig -f ~/RBAC-bind.yaml

  rm -rf ~/RBAC-*.yaml
}

install_bin() {
  apt-get update
  apt-get install -y nginx

  # Decompress components
  tar xf controller-comp.tar.xz
  tar xf etcd-v${VER_ETCD}-linux-amd64.tar.gz

  # Install etcd
  mv etcd-v${VER_ETCD}-linux-amd64/etcd* /usr/local/bin/

  # Install Kube Bin
  chmod +x kubectl kube-apiserver kube-proxy ${COMP_KUBE_CTRL_MGR} ${COMP_KUBE_SCHEDULER}
  mv kubectl kube-apiserver kube-proxy ${COMP_KUBE_CTRL_MGR} ${COMP_KUBE_SCHEDULER} /usr/local/bin/
  
  rm -rf etcd-v${VER_ETCD}-linux-amd64
}

reload() {
  netplan apply
  sysctl -p
  systemctl daemon-reload
  systemctl enable etcd nginx kube-apiserver kube-proxy ${COMP_KUBE_CTRL_MGR} ${COMP_KUBE_SCHEDULER}
  systemctl restart nginx etcd kube-apiserver kube-proxy ${COMP_KUBE_CTRL_MGR} ${COMP_KUBE_SCHEDULER}
}

deploy_cert() {
  install_cert

  ETCDCTL_API=3 etcdctl del --prefix / \\
    --endpoints=https://${INTERN_IP}:${KUBE_ETCD_LISTEN_CLIENT_PORT} \\
    --cacert=/etc/etcd/ca.pem \\
    --cert=/etc/etcd/kubernetes.pem \\
    --key=/etc/etcd/kubernetes-key.pem

  reload

  echo "Waiting For Kubernetes-APIServer (30s)"
  sleep 30

  apply_rbac

  echo "[DEPLOY] ${CTRL} cert success"
}

deploy_conf() {
  install_conf
  reload

  echo "[DEPLOY] ${CTRL} config success"
}

deploy_bin() {
  install_bin
  reload

  echo "[DEPLOY] ${CTRL} bin success"
}

deploy_all() {
  install_bin
  install_cert
  install_conf

  ETCDCTL_API=3 etcdctl del --prefix / \\
    --endpoints=https://${INTERN_IP}:${KUBE_ETCD_LISTEN_CLIENT_PORT} \\
    --cacert=/etc/etcd/ca.pem \\
    --cert=/etc/etcd/kubernetes.pem \\
    --key=/etc/etcd/kubernetes-key.pem

  reload

  echo "Waiting For Kubernetes-APIServer (30s)"
  sleep 30

  apply_rbac

  echo "[DEPLOY] ${CTRL} all success"
}

\$@

EOF
    chmod +x ${SCRIPT}
  done
}

gen_cert() {
  gen_common_cert
  gen_kube_apiserver_cert
  gen_kube_service_account_cert
  gen_encryption_key
}

gen_conf() {
  gen_etcd_conf
  gen_common_conf
  gen_kube_apiserver_conf
  gen_kube_controller_manager_conf
  gen_kube_scheduler_conf
  gen_kube_service_account_conf
  gen_deploy_script
}

mkdir -p ${GEN_DIR}

$@

rm -f ${GEN_DIR}/*.csr