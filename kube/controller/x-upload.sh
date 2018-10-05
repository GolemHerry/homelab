#!/bin/bash -x

set -e

_KUBE_DIR=..

source ${_KUBE_DIR}/env.sh

BIN_TAR="controller-comp.tar.xz"

prepare_bin() {
  pushd ${DOWNLOAD_DIR}
    tar Jcf ../${GEN_DIR}/${BIN_TAR} ./*
  popd
}

upload_bin() {
  TO_UPLOAD="${GEN_DIR}/${BIN_TAR}"
  
  for i in ${!CTRL_LIST[@]}
  do
    CONTROLLER=${CTRL_LIST[${i}]}
    SSH_ADDR=${CTRL_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${CTRL_SSH_PORT_LIST[${i}]}
    SSH_ID=${CTRL_SSH_ID_LIST[${i}]}
    USER=${CTRL_SSH_USER_LIST[${i}]}

    scp -P ${SSH_PORT} -i ${SSH_ID} ${TO_UPLOAD} ${USER}@${SSH_ADDR}:~/
  done
}

upload_cfg() {
  for i in ${!CTRL_LIST[@]}
  do
    CONTROLLER=${CTRL_LIST[${i}]}
    SSH_ADDR=${CTRL_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${CTRL_SSH_PORT_LIST[${i}]}
    SSH_ID=${CTRL_SSH_ID_LIST[${i}]}
    USER=${CTRL_SSH_USER_LIST[${i}]}

    TO_UPLOAD="${GEN_DIR}/${COMP_KUBE_SERVICE_ACCOUNT}*.pem \
      ${GEN_DIR}/${COMP_KUBE_API_SERVER}*.pem \
      ${GEN_DIR}/${COMP_KUBE_CTRL_MGR}.kubeconfig \
      ${GEN_DIR}/${COMP_KUBE_CTRL_MGR}.service \
      ${GEN_DIR}/${COMP_KUBE_SCHEDULER}.kubeconfig \
      ${GEN_DIR}/${COMP_KUBE_SCHEDULER}.service \
      ${GEN_DIR}/${COMP_KUBE_SCHEDULER}.yaml \
      ${GEN_DIR}/${CONTROLLER}-deploy.sh \
      ${GEN_DIR}/${CONTROLLER}-kube-apiserver.service \
      ${GEN_DIR}/${CONTROLLER}.etcd.service \
      ${GEN_DIR}/encryption-config.yaml \
      ${GEN_DIR}/healthcheck.nginx \
      ${GEN_DIR}/RBAC-*.yaml"

    scp -P ${SSH_PORT} -i ${SSH_ID} ${TO_UPLOAD} ${USER}@${SSH_ADDR}:~/
  done
}

$@