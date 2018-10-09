#!/bin/bash

set -e

_KUBE_DIR=..
source ${_KUBE_DIR}/env.sh

CA_DIR=${_KUBE_DIR}/cert
CA_GEN_DIR=${_KUBE_DIR}/cert/${GEN_DIR}

gen_static_config() {
  CFG_CRICTL=${GEN_DIR}/crictl.yaml
  cat > ${CFG_CRICTL} <<EOF
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF

  CFG_CONTAINERD=${GEN_DIR}/containerd.config.toml
  cat > ${CFG_CONTAINERD} <<EOF
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
  cat > ${CFG_CNI_LOOPBACK} <<EOF
{
  "cniVersion": "${VER_CNI}",
  "type": "loopback"
}
EOF
  
  CFG_SYSTEMD_CONTAINERD=${GEN_DIR}/containerd.service
  cat > ${CFG_SYSTEMD_CONTAINERD} <<EOF
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
  cat > ${CFG_SYSTEMD_KUBELET} <<EOF
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

gen_kube_proxy_conf() {
  CFG_KUBE_PROXY=${GEN_DIR}/${COMP_KUBE_PROXY}-config.yaml
  cat > ${CFG_KUBE_PROXY} <<EOF
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/${COMP_KUBE_PROXY}/kubeconfig"
mode: "iptables"
clusterCIDR: "${KUBE_CLUSTER_CIDR}"
EOF

  CFG_SYSTEMD_KUBE_PROXY=${GEN_DIR}/${COMP_KUBE_PROXY}.service
  cat > ${CFG_SYSTEMD_KUBE_PROXY} <<EOF
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/${COMP_KUBE_PROXY} \\
  --config=/var/lib/${COMP_KUBE_PROXY}/${COMP_KUBE_PROXY}-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

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
    POD_CIDR=${WORKER_POD_CIDR_LIST[${i}]}
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
  
  CFG_CNI_BRIDGE=${GEN_DIR}/${WORKER}-cni-bridge.json
  cat > ${CFG_CNI_BRIDGE} <<EOF
{
  "cniVersion": "${VER_CNI}",
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
  cat > ${CFG_KUBELET} <<EOF
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/${COMP_KUBE_API_SERVER}/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "${CLUSTER_DNS_SERVER}"
podCIDR: "${POD_CIDR}"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/${WORKER}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${WORKER}-key.pem"
EOF

  DEPLOY_SCRIPT=${GEN_DIR}/${WORKER}-deploy.sh
  cat > ${DEPLOY_SCRIPT} <<EOF
#!/bin/bash -x
set -e

apt-get update
apt-get -y install socat conntrack ipset

mkdir -p \\
  /etc/cni/net.d \\
  /opt/cni/bin \\
  /var/lib/kubelet \\
  /var/lib/${COMP_KUBE_PROXY} \\
  /var/lib/${COMP_KUBE_API_SERVER} \\
  /var/run/${COMP_KUBE_API_SERVER} \\
  /etc/containerd

# decompress worker components
tar xf worker-comp.tar.xz

tar xf crictl-v${VER_KUBE}-linux-amd64.tar.gz -C /usr/local/bin/
tar xf cni-plugins-amd64-v${VER_CNI_PLUGINS}.tgz -C /opt/cni/bin/
tar xf containerd-${VER_CONTAINERD}.linux-amd64.tar.gz -C /

# Install bin
mv runsc* runsc
mv runc.amd64 runc
chmod +x kubectl ${COMP_KUBE_PROXY} kubelet runc runsc
mv kubectl ${COMP_KUBE_PROXY} kubelet runc runsc /usr/local/bin/

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
mv ${COMP_KUBE_PROXY}-config.yaml /var/lib/${COMP_KUBE_PROXY}/${COMP_KUBE_PROXY}-config.yaml
mv ${COMP_KUBE_PROXY}.service /etc/systemd/system/${COMP_KUBE_PROXY}.service
mv ${COMP_KUBE_PROXY}.kubeconfig /var/lib/${COMP_KUBE_PROXY}/kubeconfig

# Install certs for kubelet and kube-apiserver client
mv ca.pem /var/lib/${COMP_KUBE_API_SERVER}/
mv ${WORKER}*.pem /var/lib/kubelet/

systemctl daemon-reload
systemctl enable containerd kubelet ${COMP_KUBE_PROXY}
systemctl restart containerd kubelet ${COMP_KUBE_PROXY}

printf "\n\nDeploy ${WORKER} Success\n"
EOF
    chmod +x ${DEPLOY_SCRIPT}

  done
}

gen_conf() {
  gen_static_config
  gen_kube_proxy_conf
  gen_kubelet_conf
}

mkdir -p ${GEN_DIR}

$@

rm -f ${GEN_DIR}/*.csr
