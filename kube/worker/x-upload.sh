#!/bin/bash -x

set -e

_KUBE_DIR=..

source ${_KUBE_DIR}/env.sh

upload_bin() {
  BIN_TAR="worker-comp.tar.xz"
  pushd ${DOWNLOAD_DIR}
    tar Jcf ../${GEN_DIR}/${BIN_TAR} *
  popd

  for i in ${!WORKER_LIST[@]}
  do
    WORKER=${WORKER_LIST[${i}]}
    SSH_ADDR=${WORKER_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${WORKER_SSH_PORT_LIST[${i}]}
    SSH_ID=${WORKER_SSH_ID_LIST[${i}]}
    USER=${WORKER_SSH_USER_LIST[${i}]}

    TO_UPLOAD="${GEN_DIR}/${BIN_TAR}"

    scp -P ${SSH_PORT} -i ${SSH_ID} ${TO_UPLOAD} ${USER}@${SSH_ADDR}:~/
  done
}

upload_cfg() {
  for i in ${!WORKER_LIST[@]}
  do
    WORKER=${WORKER_LIST[${i}]}
    SSH_ADDR=${WORKER_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${WORKER_SSH_PORT_LIST[${i}]}
    SSH_ID=${WORKER_SSH_ID_LIST[${i}]}
    USER=${WORKER_SSH_USER_LIST[${i}]}

    TO_UPLOAD="${GEN_DIR}/kubelet.service \
      ${GEN_DIR}/${WORKER}*.pem \
      ${GEN_DIR}/${WORKER}.kubeconfig \
      ${GEN_DIR}/${WORKER}-kubelet.yaml \
      ${GEN_DIR}/${COMP_KUBE_PROXY}.kubeconfig \
      ${GEN_DIR}/${COMP_KUBE_PROXY}-config.yaml \
      ${GEN_DIR}/${COMP_KUBE_PROXY}.service \
      ${GEN_DIR}/containerd.config.toml \
      ${GEN_DIR}/containerd.service \
      ${GEN_DIR}/cni-loopback.json \
      ${GEN_DIR}/${WORKER}-cni-bridge.json \
      ${GEN_DIR}/${WORKER}-deploy.sh"

    scp -P ${SSH_PORT} -i ${SSH_ID} ${TO_UPLOAD} ${USER}@${SSH_ADDR}:~/
  done
}
