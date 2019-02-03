#!/bin/bash

set -e

source env.sh
source base.sh

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
  gen_worker_conf
}

gen_all() {
  gen_all_cert
  gen_all_conf
}

download_all() {
  download_common_bin &
  download_ctrl_bin &
  download_worker_bin &
  wait
}

prepare_bin_all() {
  prepare_worker_bin &
  prepare_ctrl_bin &
  prepare_common_bin &
  wait
}

upload_cert_all() {
  upload_common_cert &
  upload_ctrl_cert &
  upload_worker_cert &
  wait
}

upload_conf_all() {
  upload_common_conf &
  upload_ctrl_conf &
  upload_worker_conf &
  wait
}

upload_bin_all() {
  upload_common_bin &
  upload_ctrl_bin &
  upload_worker_bin &
  wait
}

upload_all() {
  upload_cert_all &
  upload_conf_all &
  upload_bin_all &
  wait
}

deploy_all() {
  deploy_ctrl_all
  deploy_worker_all
}

update_conf() {
  gen_conf
  upload_conf_all
  deploy_ctrl_conf
  deploy_workers_conf
}

reboot_all() {
  reboot_worker
  reboot_ctrl
}

config_local_kubectl() {
  kubectl config set-cluster ${KUBE_CLUSTER_NAME} \
    --certificate-authority=./common/${GEN_DIR}/ca.pem \
    --embed-certs=true \
    --server=https://${REMOTE_KUBE_PUB_ADDR}:${REMOTE_KUBE_API_SERVER_PORT}

  kubectl config set-credentials admin \
    --client-certificate=./common/${GEN_DIR}/admin.pem \
    --client-key=./common/${GEN_DIR}/admin-key.pem

  kubectl config set-context ${KUBE_CONTEXT_NAME} \
    --cluster=${KUBE_CLUSTER_NAME} \
    --user=admin

  kubectl config use-context ${KUBE_CONTEXT_NAME}
}

"$@"
