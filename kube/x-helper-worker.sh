#!/bin/bash

WORKER_DIR=worker

source ./env.sh

gen_worker_cert() {
  pushd ${WORKER_DIR}
    ./x-gen.sh gen_cert
  popd
}

gen_worker_conf() {
  pushd ${WORKER_DIR}
    ./x-gen.sh gen_conf
  popd
}

gen_worker_all() {
  gen_worker_cert
  gen_worker_conf
}

download_worker() {
  pushd ${WORKER_DIR}
    ./x-get.sh
  popd
}

upload_worker_cert() {
  pushd ${WORKER_DIR}
    ./x-upload.sh upload_cert
  popd
}

upload_worker_conf() {
  pushd ${WORKER_DIR}
    ./x-upload.sh upload_conf
  popd
}

upload_worker_bin() {
  pushd ${WORKER_DIR}
    ./x-upload.sh upload_bin
  popd
}

uplaod_worker_all() {
  upload_worker_cert
  upload_worker_conf
  upload_worker_bin
}

deploy_worker() {
  for i in ${!WORKER_LIST[@]}
  do
    WORKER=${WORKER_LIST[${i}]}
    SSH_ADDR=${WORKER_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${WORKER_SSH_PORT_LIST[${i}]}
    SSH_ID=${WORKER_SSH_ID_LIST[${i}]}
    USER=${WORKER_SSH_USER_LIST[${i}]}
    PASS=${WORKER_SSH_USER_PASS_LIST[${i}]}

    echo "[DEPLOY] ${WORKER}"
    ssh -p ${SSH_PORT} -i ${SSH_ID} ${USER}@${SSH_ADDR} \
      "echo ${PASS} | sudo -S bash ~/${WORKER}-deploy.sh $1" &
  done
  wait
}

deploy_worker_cert() {
  deploy_worker deploy_cert
}

deploy_worker_conf() {
  deploy_worker deploy_conf
}

deploy_worker_bin() {
  deploy_worker deploy_bin
}

deploy_worker_all() {
  deploy_worker deploy_all
}

reboot_worker() {
  for i in ${!WORKER_LIST[@]}
  do
    WORKER=${WORKER_LIST[${i}]}
    SSH_ADDR=${WORKER_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${WORKER_SSH_PORT_LIST[${i}]}
    SSH_ID=${WORKER_SSH_ID_LIST[${i}]}
    USER=${WORKER_SSH_USER_LIST[${i}]}
    PASS=${WORKER_SSH_USER_PASS_LIST[${i}]}

    echo "[REBOOT] ${WORKER}"
    ssh -p ${SSH_PORT} -i ${SSH_ID} ${USER}@${SSH_ADDR} \
      "echo ${PASS} | sudo -S reboot" &
  done
  wait
}