#!/bin/bash

set -e

_KUBE_DIR=..

source ${_KUBE_DIR}/env.sh

upload_cert() {
  # send to workers
  for i in ${!WORKER_LIST[@]}
  do
    SSH_ADDR=${WORKER_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${WORKER_SSH_PORT_LIST[${i}]}
    SSH_ID=${WORKER_SSH_ID_LIST[${i}]}
    USER=${WORKER_SSH_USER_LIST[${i}]}

    TO_UPLOAD="${GEN_DIR}/ca.pem"

    scp -P ${SSH_PORT} -i ${SSH_ID} ${TO_UPLOAD} ${USER}@${SSH_ADDR}:~/ &
  done

  # send to controllers
  for i in ${!CTRL_LIST[@]}
  do
    SSH_ADDR=${CTRL_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${CTRL_SSH_PORT_LIST[${i}]}
    SSH_ID=${CTRL_SSH_ID_LIST[${i}]}
    USER=${CTRL_SSH_USER_LIST[${i}]}

    TO_UPLOAD="${GEN_DIR}/ca.pem \
      ${GEN_DIR}/ca-key.pem \
      ${GEN_DIR}/ca-aggregator.pem \
      ${GEN_DIR}/ca-aggregator-key.pem \
      ${GEN_DIR}/aggregator-proxy-client.pem \
      ${GEN_DIR}/aggregator-proxy-client-key.pem"

    scp -P ${SSH_PORT} -i ${SSH_ID} ${TO_UPLOAD} ${USER}@${SSH_ADDR}:~/ &
  done
  wait
}

upload_conf() {
  # send to controllers
  for i in ${!CTRL_LIST[@]}
  do
    SSH_ADDR=${CTRL_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${CTRL_SSH_PORT_LIST[${i}]}
    SSH_ID=${CTRL_SSH_ID_LIST[${i}]}
    USER=${CTRL_SSH_USER_LIST[${i}]}

    TO_UPLOAD="${GEN_DIR}/admin.kubeconfig"

    scp -P ${SSH_PORT} -i ${SSH_ID} ${TO_UPLOAD} ${USER}@${SSH_ADDR}:~/ &
  done
  wait
}

$@
