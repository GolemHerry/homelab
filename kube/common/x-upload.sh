#!/bin/bash

set -e

_KUBE_DIR=..

source ${_KUBE_DIR}/env.sh
source ${_KUBE_DIR}/base.sh

BIN_TAR="common-comp.tar.xz"

prepare_bin() {
  pushd ${DOWNLOAD_DIR}
    tar Jcf ../${GEN_DIR}/${BIN_TAR} ./*
  popd
}

upload_cert() {
  TO_UPLOAD="${GEN_DIR}/ca.pem"

  # upload to workers
  for i in ${!WORKER_LIST[@]}
  do
    SSH_ADDR=${WORKER_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${WORKER_SSH_PORT_LIST[${i}]}
    SSH_ID=${WORKER_SSH_ID_LIST[${i}]}
    USER=${WORKER_SSH_USER_LIST[${i}]}

    W_TO_UPLOAD="${TO_UPLOAD}"

    scp -P ${SSH_PORT} -i ${SSH_ID} ${W_TO_UPLOAD} ${USER}@${SSH_ADDR}:~/ &
  done

  # upload to controllers
  for i in ${!CTRL_LIST[@]}
  do
    SSH_ADDR=${CTRL_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${CTRL_SSH_PORT_LIST[${i}]}
    SSH_ID=${CTRL_SSH_ID_LIST[${i}]}
    USER=${CTRL_SSH_USER_LIST[${i}]}

    C_TO_UPLOAD="${TO_UPLOAD} \
                 ${GEN_DIR}/ca-key.pem \
                 ${GEN_DIR}/ca-aggregator.pem \
                 ${GEN_DIR}/ca-aggregator-key.pem \
                 ${GEN_DIR}/aggregator-proxy-client.pem \
                 ${GEN_DIR}/aggregator-proxy-client-key.pem"

    scp -P ${SSH_PORT} -i ${SSH_ID} ${C_TO_UPLOAD} ${USER}@${SSH_ADDR}:~/ &
  done
  wait
}

upload_conf() {
  TO_UPLOAD="${GEN_DIR}/kube-proxy-config.yaml \
             ${GEN_DIR}/kube-proxy.pem \
             ${GEN_DIR}/kube-proxy-key.pem \
             ${GEN_DIR}/kube-proxy.kubeconfig \
             ${GEN_DIR}/kube-proxy.service \
             ${GEN_DIR}/kube-sysctl.conf"

  # upload to workers
  for i in ${!WORKER_LIST[@]}
  do
    SSH_ADDR=${WORKER_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${WORKER_SSH_PORT_LIST[${i}]}
    SSH_ID=${WORKER_SSH_ID_LIST[${i}]}
    USER=${WORKER_SSH_USER_LIST[${i}]}

    W_TO_UPLOAD="${TO_UPLOAD}"

    scp -P ${SSH_PORT} -i ${SSH_ID} ${TO_UPLOAD} ${USER}@${SSH_ADDR}:~/ &
  done

  # upload to controllers
  for i in ${!CTRL_LIST[@]}
  do
    SSH_ADDR=${CTRL_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${CTRL_SSH_PORT_LIST[${i}]}
    SSH_ID=${CTRL_SSH_ID_LIST[${i}]}
    USER=${CTRL_SSH_USER_LIST[${i}]}

    C_TO_UPLOAD="${TO_UPLOAD} \
                 ${GEN_DIR}/admin.kubeconfig"

    scp -P ${SSH_PORT} -i ${SSH_ID} ${C_TO_UPLOAD} ${USER}@${SSH_ADDR}:~/ &
  done
  wait
}

upload_bin() {
  for i in ${!WORKER_LIST[@]}
  do
    WORKER=${WORKER_LIST[${i}]}
    SSH_ADDR=${WORKER_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${WORKER_SSH_PORT_LIST[${i}]}
    SSH_ID=${WORKER_SSH_ID_LIST[${i}]}
    USER=${WORKER_SSH_USER_LIST[${i}]}

    TO_UPLOAD="${GEN_DIR}/${BIN_TAR}"

    scp -P ${SSH_PORT} -i ${SSH_ID} ${TO_UPLOAD} ${USER}@${SSH_ADDR}:~/ &
  done

  for i in ${!CTRL_LIST[@]}
  do
    CTRL=${CTRL_LIST[${i}]}
    SSH_ADDR=${CTRL_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${CTRL_SSH_PORT_LIST[${i}]}
    SSH_ID=${CTRL_SSH_ID_LIST[${i}]}
    USER=${CTRL_SSH_USER_LIST[${i}]}

    TO_UPLOAD="${GEN_DIR}/${BIN_TAR}"

    scp -P ${SSH_PORT} -i ${SSH_ID} ${TO_UPLOAD} ${USER}@${SSH_ADDR}:~/ &
  done
  wait
}

$@
