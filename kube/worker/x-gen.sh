#!/bin/bash

set -e

_KUBE_DIR=..

source ${_KUBE_DIR}/env.sh
source ${_KUBE_DIR}/base.sh

CA_DIR=${_KUBE_DIR}/common
CA_GEN_DIR=${_KUBE_DIR}/common/${GEN_DIR}

gen_static_config() {
  CFG_CRICTL=${GEN_DIR}/crictl.yaml
  cat > ${CFG_CRICTL} << EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

  CFG_CONTAINERD=${GEN_DIR}/containerd.config.toml
  cat > ${CFG_CONTAINERD} << EOF
[plugins]
  [plugins.cri]
  sandbox_image = "registry.cn-hangzhou.aliyuncs.com/google_containers/pause-amd64:3.1"
  [plugins.cri.containerd]
    snapshotter = "overlayfs"
    [plugins.cri.containerd.default_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runc"
      runtime_root = ""
    [plugins.cri.containerd.untrusted_workload_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runsc"
      runtime_root = "/run/containerd/runsc"
    [plugins.cri.containerd.gvisor]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runsc"
      runtime_root = "/run/containerd/runsc"
  [plugins.cri.registry]
    [plugins.cri.registry.mirrors]
      [plugins.cri.registry.mirrors."docker.io"]
        endpoint = ["https://registry-1.docker.io"]
EOF
  CFG_CNI_LOOPBACK=${GEN_DIR}/cni-loopback.json
  cat > ${CFG_CNI_LOOPBACK} << EOF
{
  "cniVersion": "${VER_CNI_SPEC}",
  "type": "loopback"
}
EOF

  CFG_SYSTEMD_CONTAINERD=${GEN_DIR}/containerd.service
  cat > ${CFG_SYSTEMD_CONTAINERD} << EOF
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF
  CFG_SYSTEMD_KUBELET=${GEN_DIR}/kubelet.service
  cat > ${CFG_SYSTEMD_KUBELET} << EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
}

gen_kubelet_cert() {
  for i in ${!WORKER_LIST[@]}
  do
    WORKER=${WORKER_LIST[${i}]}
    INTERN_IP=${WORKER_INTERN_IP_LIST[${i}]}
    EXTERN_IP=${WORKER_EXTERN_IP_LIST[${i}]}

    CERT_CSR_CFG=${GEN_DIR}/csr-${WORKER}.json
    cat > ${CERT_CSR_CFG} << EOF
{
  "CN": "system:node:${WORKER}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [{
    "C": "${KUBE_CERT_COUNTRY}",
    "L": "${KUBE_CERT_LOCATION}",
    "O": "system:nodes",
    "OU": "${KUBE_CERT_ORG_UNIT}",
    "ST": "${KUBE_CERT_STATE}"
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
  done
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
    POD_CIDR=${WORKER_POD_CIDR_LIST[${i}]}
    INTERN_IP=${WORKER_INTERN_IP_LIST[${i}]}
    EXTERN_IP=${WORKER_EXTERN_IP_LIST[${i}]}
    IFACE=${WORKER_NET_IFACE_LIST[${i}]}

    # generate kubelet kubeconfig
    kubectl config set-cluster ${KUBE_CLUSTER_NAME} \
        --certificate-authority=${CA_GEN_DIR}/ca.pem \
        --embed-certs=true \
        --server=https://${HOMELAB_KUBE_PUB_ADDR}:${HOMELAB_KUBE_API_SERVER_PORT} \
        --kubeconfig=${GEN_DIR}/${WORKER}.kubeconfig

    kubectl config set-credentials system:node:${WORKER} \
        --client-certificate=${GEN_DIR}/${WORKER}.pem \
        --client-key=${GEN_DIR}/${WORKER}-key.pem \
        --embed-certs=true \
        --kubeconfig=${GEN_DIR}/${WORKER}.kubeconfig

    kubectl config set-context ${KUBE_CONTEXT_NAME} \
        --cluster=${KUBE_CLUSTER_NAME} \
        --user=system:node:${WORKER} \
        --kubeconfig=${GEN_DIR}/${WORKER}.kubeconfig

    kubectl config use-context ${KUBE_CONTEXT_NAME} \
        --kubeconfig=${GEN_DIR}/${WORKER}.kubeconfig
    
    CFG_CNI_BRIDGE=${GEN_DIR}/${WORKER}-cni-bridge.json
    cat > ${CFG_CNI_BRIDGE} << EOF
{
  "cniVersion": "${VER_CNI_SPEC}",
  "name": "bridge",
  "type": "bridge",
  "bridge": "cnio0",
  "isGateway": true,
  "ipMasq": true,
  "ipam": {
    "type": "host-local",
    "ranges":[
      [{"subnet": "${POD_CIDR}"}]
    ],
    "routes": [{"dst": "0.0.0.0/0"}]
  }
}
EOF

    CFG_KUBELET=${GEN_DIR}/${WORKER}-kubelet.yaml
    cat > ${CFG_KUBELET} << EOF
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "${KUBE_SVC_DNS}"
podCIDR: "${POD_CIDR}"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/${WORKER}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${WORKER}-key.pem"
EOF

    CFG_NET_ROUTE=""

    for j in ${!WORKER_LIST[@]}
    do
      X_POD_CIDR=${WORKER_POD_CIDR_LIST[${j}]}
      X_INTERN_IP=${WORKER_INTERN_IP_LIST[${j}]}

      if [ ${X_INTERN_IP} = ${INTERN_IP} ]; then 
        continue
      else
        CFG_NET_ROUTE=$(cat << EOF
      - to: ${X_POD_CIDR}
        via: ${X_INTERN_IP}
${CFG_NET_ROUTE}
EOF
)
      fi
    done

  CFG_NETWORK=${GEN_DIR}/${WORKER}-network.yaml
  cat > ${CFG_NETWORK} << EOF
network:
  ethernets:
    ${IFACE}:
      addresses:
      - ${INTERN_IP}/${HOMELAB_NET_PREFIX_LEN}
      dhcp4: no
      gateway4: ${HOMELAB_GW_IPV4}
      nameservers:
        addresses:
        - ${HOMELAB_DNS_SRV}
        search: []
      routes:
${CFG_NET_ROUTE}
  version: 2
EOF

  DEPLOY_SCRIPT=${GEN_DIR}/${WORKER}-deploy.sh
  cat > ${DEPLOY_SCRIPT} << EOF
#!/bin/bash -x
set -e

mkdir -p \\
  /etc/cni/net.d \\
  /opt/cni/bin \\
  /var/lib/kubelet \\
  /var/lib/kube-proxy \\
  /var/lib/kubernetes \\
  /var/run/kubernetes \\
  /etc/containerd

install_cert() {
  # Install certs for kubelet and kube-apiserver client
  mv ca.pem /var/lib/kubernetes/
  mv ${WORKER}.pem ${WORKER}-key.pem /var/lib/kubelet/
}

install_conf() {
  # Install configurations for containerd
  mv containerd.config.toml /etc/containerd/config.toml
  mv containerd.service /etc/systemd/system/containerd.service
  mv crictl.yaml /etc/crictl.yaml

  # Install configurations for cni
  mv ${WORKER}-cni-bridge.json /etc/cni/net.d/10-bridge.conf
  mv cni-loopback.json /etc/cni/net.d/99-loopback.conf

  # Install configurations for kubelet
  mv ${WORKER}.kubeconfig /var/lib/kubelet/kubeconfig
  mv kubelet.service /etc/systemd/system/kubelet.service
  mv ${WORKER}-kubelet.yaml /var/lib/kubelet/kubelet-config.yaml

  # Install configurations for kube-proxy
  mv kube-proxy-config.yaml /var/lib/kube-proxy/kube-proxy-config.yaml
  mv kube-proxy.service /etc/systemd/system/kube-proxy.service
  mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig

  # Install configurations for network
  mv ${WORKER}-network.yaml /etc/netplan/50-cloud-init.yaml
  mv kube-sysctl.conf /etc/sysctl.d/10-kube-sysctl.conf
}

install_bin() {
  apt-get update
  apt-get -y install socat conntrack ipset

  # decompress worker components
  tar xf common-comp.tar.xz
  tar xf worker-comp.tar.xz
  tar xf crictl-v${VER_CRICTL}-linux-amd64.tar.gz -C /usr/local/bin/
  tar xf cni-plugins-amd64-v${VER_CNI_PLUGINS}.tgz -C /opt/cni/bin/
  tar xf containerd-${VER_CONTAINERD}.linux-amd64.tar.gz -C /

  # Install bin

  mv runc.amd64 runc
  chmod +x kubectl kube-proxy kubelet runc runsc
  mv kubectl kube-proxy kubelet runc runsc /usr/local/bin/
}

reload() {
  netplan apply
  sysctl -p
  systemctl daemon-reload
  systemctl enable containerd kubelet kube-proxy
  systemctl restart containerd kubelet kube-proxy
}

deploy_cert() {
  install_cert
  reload

  echo "[DEPLOY] ${WORKER} Cert success"
}

deploy_conf() {
  install_conf
  reload

  echo "[DEPLOY] ${WORKER} Config success"
}

deploy_bin() {
  install_bin
  reload

  echo "[DEPLOY] ${WORKER} Bin success"
}

deploy_all() {
  install_bin
  install_cert
  install_conf
  reload

  echo "[DEPLOY] ${WORKER} all success"
}

\$@

EOF
    chmod +x ${DEPLOY_SCRIPT}

  done
}

gen_cert() {
  gen_kubelet_cert
}

gen_conf() {
  gen_static_config
  gen_kubelet_conf
}

mkdir -p ${GEN_DIR}

$@

rm -f ${GEN_DIR}/*.csr
