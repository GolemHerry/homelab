#!/bin/bash

set -e

gen_ca() {
  pushd cert
    ./x-gen.sh gen_ca
  popd
}

gen_all() {
  TARGETS=(cert controller worker)
  for T in ${TARGETS[@]}
  do
    pushd ${T}
      ./x-gen.sh gen_conf
    popd
  done
}

download_all() {
  TARGETS=(controller worker)
  for T in ${TARGETS[@]}
  do
    pushd ${T}
      ./x-get.sh
    popd
  done
}

prepare_bin_all() {
  TARGETS=(controller worker)
  for T in ${TARGETS[@]}
  do
    pushd ${T}
      ./x-upload.sh prepare_bin
    popd
  done
}

upload_cfg_all() {
  TARGETS=(controller worker cert)
  for T in ${TARGETS[@]}
  do
    pushd ${T}
      ./x-upload.sh upload_cfg
    popd
  done
}

upload_bin_all() {
  TARGETS=(controller worker)
  for T in ${TARGETS[@]}
  do
    pushd ${T}
      ./x-upload.sh upload_bin
    popd
  done
}

upload_all() {
  upload_cfg_all
  upload_bin_all
}

deploy_controllers() {
  source ./env.sh

  for i in ${CTRL_LIST[@]}
  do
    CONTROLLER=${CTRL_LIST[${i}]}
    SSH_ADDR=${CTRL_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${CTRL_SSH_PORT_LIST[${i}]}
    SSH_ID=${CTRL_SSH_ID_LIST[${i}]}
    USER=${CTRL_SSH_USER_LIST[${i}]}
    PASS=${CTRL_SSH_USER_PASS_LIST[${i}]}
    
    printf "\n\nDeploying Controller: ${CONTROLLER}\n\n\n"
    ssh -p ${SSH_PORT} -i ${SSH_ID} ${USER}@${SSH_ADDR} \
      "echo ${PASS} | sudo -S bash ~/${CONTROLLER}-deploy.sh"
  done
}

deploy_workers() {
  source ./env.sh

  for i in ${WORKER_LIST[@]}
  do
    WORKER=${WORKER_LIST[${i}]}
    SSH_ADDR=${WORKER_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${WORKER_SSH_PORT_LIST[${i}]}
    SSH_ID=${WORKER_SSH_ID_LIST[${i}]}
    USER=${WORKER_SSH_USER_LIST[${i}]}
    PASS=${WORKER_SSH_USER_PASS_LIST[${i}]}
    
    printf "\n\nDeploying Worker: ${WORKER}\n\n\n"
    ssh -p ${SSH_PORT} -i ${SSH_ID} ${USER}@${SSH_ADDR} \
      "echo ${PASS} | sudo -S bash ~/${WORKER}-deploy.sh"
  done
}

deploy_all() {
  deploy_controllers
  deploy_workers
}

redeploy_all() {
  upload_cfg_all
  deploy_all
}

config_local_kubectl() {
  source ./env.sh

  kubectl config set-cluster ${CLUSTER_NAME} \
    --certificate-authority=./cert/${GEN_DIR}/ca.pem \
    --embed-certs=true \
    --server=https://${REMOTE_KUBE_PUB_ADDR}:${REMOTE_KUBE_LISTEN_PORT}

  kubectl config set-credentials admin \
    --client-certificate=./cert/${GEN_DIR}/admin.pem \
    --client-key=./cert/${GEN_DIR}/admin-key.pem

  kubectl config set-context ${CONTEXT_NAME} \
    --cluster=${CLUSTER_NAME} \
    --user=admin

  kubectl config use-context ${CONTEXT_NAME}
}

$@
