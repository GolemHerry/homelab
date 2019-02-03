#!/bin/bash

set -e

_KUBE_DIR=..

source ${_KUBE_DIR}/env.sh
source ${_KUBE_DIR}/base.sh

BIN_TAR="worker-comp.tar.xz"

prepare_bin() {
  pushd ${DOWNLOAD_DIR}
    tar Jcf ../${GEN_DIR}/${BIN_TAR} ./*
  popd
}

upload_bin() {
  for i in ${!WORKER_LIST[@]}
  do
    WORKER=${WORKER_LIST[${i}]}
    SSH_ADDR=${WORKER_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${WORKER_SSH_PORT_LIST[${i}]}
    SSH_ID=${WORKER_SSH_ID_LIST[${i}]}
    USER=${WORKER_SSH_USER_LIST[${i}]}

    TO_UPLOAD="${GEN_DIR}/${BIN_TAR} \
      ${GEN_DIR}/${WORKER}-deploy.sh"

    scp -P ${SSH_PORT} -i ${SSH_ID} ${TO_UPLOAD} ${USER}@${SSH_ADDR}:~/ &
  done
  wait
}

upload_cert() {
  for i in ${!WORKER_LIST[@]}
  do
    WORKER=${WORKER_LIST[${i}]}
    SSH_ADDR=${WORKER_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${WORKER_SSH_PORT_LIST[${i}]}
    SSH_ID=${WORKER_SSH_ID_LIST[${i}]}
    USER=${WORKER_SSH_USER_LIST[${i}]}

    TO_UPLOAD="${GEN_DIR}/${WORKER}.pem \
      ${GEN_DIR}/${WORKER}-key.pem \
      ${GEN_DIR}/${WORKER}-deploy.sh"

    scp -P ${SSH_PORT} -i ${SSH_ID} ${TO_UPLOAD} ${USER}@${SSH_ADDR}:~/ &
  done
  wait
}

upload_conf() {
  for i in ${!WORKER_LIST[@]}
  do
    WORKER=${WORKER_LIST[${i}]}
    SSH_ADDR=${WORKER_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${WORKER_SSH_PORT_LIST[${i}]}
    SSH_ID=${WORKER_SSH_ID_LIST[${i}]}
    USER=${WORKER_SSH_USER_LIST[${i}]}

    TO_UPLOAD="${GEN_DIR}/cni-loopback.json \
      ${GEN_DIR}/containerd.config.toml \
      ${GEN_DIR}/containerd.service \
      ${GEN_DIR}/crictl.yaml \
      ${GEN_DIR}/${WORKER}-cni-bridge.json \
      ${GEN_DIR}/${WORKER}.kubeconfig \
      ${GEN_DIR}/${WORKER}-kubelet.yaml \
      ${GEN_DIR}/${WORKER}-network.yaml \
      ${GEN_DIR}/${WORKER}-deploy.sh \
      ${GEN_DIR}/kubelet.service \
      ${GEN_DIR}/sysctl.conf \
      ${GEN_DIR}/${WORKER}-deploy.sh"

    scp -P ${SSH_PORT} -i ${SSH_ID} ${TO_UPLOAD} ${USER}@${SSH_ADDR}:~/ &
  done
  wait
}

"$@"
