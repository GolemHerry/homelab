#!/bin/bash

set -e

source ./env.sh

gen_ca() {
  pushd cert
    ./x-gen.sh gen_ca
  popd
}

gen_cert() {
  TARGETS=(cert controller worker)
  for T in ${TARGETS[@]}
  do
    pushd ${T}
      ./x-gen.sh gen_cert &
    popd
  done
  wait
}

gen_conf() {
  TARGETS=(cert controller worker)
  for T in ${TARGETS[@]}
  do
    pushd ${T}
      ./x-gen.sh gen_conf &
    popd
  done
  wait
}

gen_all() {
  gen_cert
  gen_conf
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
      ./x-upload.sh prepare_bin &
    popd
  done
  wait
}

upload_cert_all() {
  TARGETS=(controller worker cert)
  for T in ${TARGETS[@]}
  do
    pushd ${T}
      ./x-upload.sh upload_cert &
    popd
  done
  wait
}

upload_conf_all() {
  TARGETS=(controller worker cert)
  for T in ${TARGETS[@]}
  do
    pushd ${T}
      ./x-upload.sh upload_conf &
    popd
  done
  wait
}

upload_bin_all() {
  TARGETS=(controller worker)
  for T in ${TARGETS[@]}
  do
    pushd ${T}
      ./x-upload.sh upload_bin &
    popd
  done
  wait
}

upload_all() {
  upload_cert_all
  upload_conf_all
  upload_bin_all
}

deploy_controllers() {
  for i in ${!CTRL_LIST[@]}
  do
    CTRL=${CTRL_LIST[${i}]}
    SSH_ADDR=${CTRL_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${CTRL_SSH_PORT_LIST[${i}]}
    SSH_ID=${CTRL_SSH_ID_LIST[${i}]}
    USER=${CTRL_SSH_USER_LIST[${i}]}
    PASS=${CTRL_SSH_USER_PASS_LIST[${i}]}
    echo $1
    printf "\n\nDeploying Controller: ${CTRL}\n\n\n"
    ssh -p ${SSH_PORT} -i ${SSH_ID} ${USER}@${SSH_ADDR} \
      "echo ${PASS} | sudo -S bash ~/${CTRL}-deploy.sh $1" &
  done
  wait
}

deploy_controllers_cert() {
  deploy_controllers deploy_cert
}

deploy_controllers_conf() {
  deploy_controllers deploy_conf
}

deploy_controllers_bin() {
  deploy_controllers deploy_bin
}

deploy_controllers_all() {
  deploy_controllers deploy_all
}

deploy_workers() {
  for i in ${!WORKER_LIST[@]}
  do
    WORKER=${WORKER_LIST[${i}]}
    SSH_ADDR=${WORKER_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${WORKER_SSH_PORT_LIST[${i}]}
    SSH_ID=${WORKER_SSH_ID_LIST[${i}]}
    USER=${WORKER_SSH_USER_LIST[${i}]}
    PASS=${WORKER_SSH_USER_PASS_LIST[${i}]}
    
    printf "\n\nDeploying Worker: ${WORKER}\n\n\n"
    ssh -p ${SSH_PORT} -i ${SSH_ID} ${USER}@${SSH_ADDR} \
      "echo ${PASS} | sudo -S bash ~/${WORKER}-deploy.sh $1" &
  done
  wait
}

deploy_workers_cert() {
  deploy_workers deploy_cert
}

deploy_workers_conf() {
  deploy_workers deploy_conf
}

deploy_workers_bin() {
  deploy_workers deploy_bin
}

deploy_workers_all() {
  deploy_workers deploy_all
}

deploy_all() {
  deploy_controllers_all &
  deploy_workers_all &
  wait
}

update_conf() {
  gen_conf
  upload_conf_all
  deploy_controllers_conf
  deploy_workers_conf
}

reboot_controllers() {
  for i in ${!CTRL_LIST[@]}
  do
    CTRL=${CTRL_LIST[${i}]}
    SSH_ADDR=${CTRL_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${CTRL_SSH_PORT_LIST[${i}]}
    SSH_ID=${CTRL_SSH_ID_LIST[${i}]}
    USER=${CTRL_SSH_USER_LIST[${i}]}
    PASS=${CTRL_SSH_USER_PASS_LIST[${i}]}
    
    printf "Rebooting Controller: ${CTRL}\n"
    ssh -p ${SSH_PORT} -i ${SSH_ID} ${USER}@${SSH_ADDR} \
      "echo ${PASS} | sudo -S reboot" &
  done
  wait
}

reboot_workers() {
  for i in ${!WORKER_LIST[@]}
  do
    WORKER=${WORKER_LIST[${i}]}
    SSH_ADDR=${WORKER_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${WORKER_SSH_PORT_LIST[${i}]}
    SSH_ID=${WORKER_SSH_ID_LIST[${i}]}
    USER=${WORKER_SSH_USER_LIST[${i}]}
    PASS=${WORKER_SSH_USER_PASS_LIST[${i}]}
    
    printf "Rebooting Worker: ${WORKER}\n"
    ssh -p ${SSH_PORT} -i ${SSH_ID} ${USER}@${SSH_ADDR} \
      "echo ${PASS} | sudo -S reboot" &
  done
  wait
}

reboot_all() {
  reboot_workers &
  reboot_controllers &
  wait
}

config_local_kubectl() {
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
