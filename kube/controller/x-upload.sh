#!/bin/bash

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
  for i in ${!CTRL_LIST[@]}
  do
    CTRL=${CTRL_LIST[${i}]}
    SSH_ADDR=${CTRL_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${CTRL_SSH_PORT_LIST[${i}]}
    SSH_ID=${CTRL_SSH_ID_LIST[${i}]}
    USER=${CTRL_SSH_USER_LIST[${i}]}

    TO_UPLOAD="${GEN_DIR}/${BIN_TAR} \
      ${GEN_DIR}/${CTRL}-deploy.sh"

    scp -P ${SSH_PORT} -i ${SSH_ID} ${TO_UPLOAD} ${USER}@${SSH_ADDR}:~/ &
  done
  wait
}

upload_cert() {
  for i in ${!CTRL_LIST[@]}
  do
    CTRL=${CTRL_LIST[${i}]}
    SSH_ADDR=${CTRL_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${CTRL_SSH_PORT_LIST[${i}]}
    SSH_ID=${CTRL_SSH_ID_LIST[${i}]}
    USER=${CTRL_SSH_USER_LIST[${i}]}

    TO_UPLOAD="${GEN_DIR}/${COMP_KUBE_SERVICE_ACCOUNT}.pem \
      ${GEN_DIR}/${COMP_KUBE_SERVICE_ACCOUNT}-key.pem \
      ${GEN_DIR}/${COMP_KUBE_API_SERVER}.pem \
      ${GEN_DIR}/${COMP_KUBE_API_SERVER}-key.pem \
      ${GEN_DIR}/${COMP_KUBE_CTRL_MGR}.service \
      ${GEN_DIR}/encryption-config.yaml \
      ${GEN_DIR}/RBAC-*.yaml \
      ${GEN_DIR}/${CTRL}-deploy.sh"

    scp -P ${SSH_PORT} -i ${SSH_ID} ${TO_UPLOAD} ${USER}@${SSH_ADDR}:~/ &
  done
  wait
}

upload_conf() {
  for i in ${!CTRL_LIST[@]}
  do
    CTRL=${CTRL_LIST[${i}]}
    SSH_ADDR=${CTRL_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${CTRL_SSH_PORT_LIST[${i}]}
    SSH_ID=${CTRL_SSH_ID_LIST[${i}]}
    USER=${CTRL_SSH_USER_LIST[${i}]}

    TO_UPLOAD="${GEN_DIR}/${COMP_KUBE_CTRL_MGR}.kubeconfig \
      ${GEN_DIR}/${COMP_KUBE_CTRL_MGR}.service \
      ${GEN_DIR}/${COMP_KUBE_SCHEDULER}.kubeconfig \
      ${GEN_DIR}/${COMP_KUBE_SCHEDULER}.service \
      ${GEN_DIR}/${COMP_KUBE_SCHEDULER}.yaml \
      ${GEN_DIR}/${CTRL}-kube-apiserver.service \
      ${GEN_DIR}/${CTRL}.etcd.service \
      ${GEN_DIR}/healthcheck.nginx \
      ${GEN_DIR}/${CTRL}-deploy.sh"

    scp -P ${SSH_PORT} -i ${SSH_ID} ${TO_UPLOAD} ${USER}@${SSH_ADDR}:~/ &
  done
  wait
}

$@