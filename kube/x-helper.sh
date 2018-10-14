#!/bin/bash

set -e

source ./env.sh

source ./x-helper-common.sh
source ./x-helper-controller.sh
source ./x-helper-worker.sh

gen_ca() {
  pushd common
    ./x-gen.sh gen_ca
  popd
}

gen_all_cert() {
  gen_common_cert
  gen_ctrl_cert
  gen_worker_cert
}

gen_all_conf() {
  gen_common_conf
  gen_ctrl_conf
  gen_all_conf
}

gen_all() {
  gen_all_cert
  gen_all_conf
}

download_all() {
  download_common
  download_controller
  download_worker
}

prepare_bin_all() {
  TARGETS=(controller worker)
  for T in ${TARGETS[@]}
  do
    pushd ${T}
      ./x-upload.sh prepare_bin &
    popd
  done
  wait
}

upload_cert_all() {
  upload_common_cert
  upload_ctrl_cert
  upload_worker_cert
}

upload_conf_all() {
  upload_common_conf
  upload_ctrl_conf
  upload_worker_conf
}

upload_bin_all() {
  upload_common_bin
  upload_ctrl_bin
  upload_worker_bin
}

upload_all() {
  upload_cert_all
  upload_conf_all
  upload_bin_all
}

deploy_all() {
  deploy_ctrl_all
  deploy_workers_all
}

update_conf() {
  gen_conf
  upload_conf_all
  deploy_ctrl_conf
  deploy_workers_conf
}

reboot_all() {
  reboot_workers
  reboot_ctrl
}

config_local_kubectl() {
  kubectl config set-cluster ${CLUSTER_NAME} \
    --certificate-authority=./common/${GEN_DIR}/ca.pem \
    --embed-certs=true \
    --server=https://${REMOTE_KUBE_PUB_ADDR}:${REMOTE_KUBE_LISTEN_PORT}

  kubectl config set-credentials admin \
    --client-certificate=./common/${GEN_DIR}/admin.pem \
    --client-key=./common/${GEN_DIR}/admin-key.pem

  kubectl config set-context ${KUBE_CONTEXT_NAME} \
    --cluster=${CLUSTER_NAME} \
    --user=admin

  kubectl config use-context ${KUBE_CONTEXT_NAME}
}

$@
