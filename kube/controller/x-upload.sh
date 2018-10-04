#!/bin/bash -x

set -e

_KUBE_DIR=..

source ${_KUBE_DIR}/env.sh

upload_bin() {
  BIN_TAR="controller-comp.tar.xz"
  pushd ${DOWNLOAD_DIR}
    tar Jcf ../${GEN_DIR}/${BIN_TAR} *
  popd

  TO_UPLOAD=${GEN_DIR}/${BIN_TAR}
  
  for i in ${!CONTROLLER_LIST[@]}
  do
    CONTROLLER=${CONTROLLER_LIST[${i}]}
    SSH_ADDR=${CONTROLLER_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${CONTROLLER_SSH_PORT_LIST[${i}]}
    SSH_ID=${CONTROLLER_SSH_ID_LIST[${i}]}
    USER=${CONTROLLER_SSH_USER_LIST[${i}]}

    scp -P ${SSH_PORT} -i ${SSH_ID} ${TO_UPLOAD} ${USER}@${SSH_ADDR}:~/
  done
}

upload_cfg() {
  for i in ${!CONTROLLER_LIST[@]}
  do
    CONTROLLER=${CONTROLLER_LIST[${i}]}
    SSH_ADDR=${CONTROLLER_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${CONTROLLER_SSH_PORT_LIST[${i}]}
    SSH_ID=${CONTROLLER_SSH_ID_LIST[${i}]}
    USER=${CONTROLLER_SSH_USER_LIST[${i}]}

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