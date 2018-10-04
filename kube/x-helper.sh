#!/bin/bash

set -e

gen_all() {
  TARGETS=(cert controller worker)
  for T in ${TARGETS[@]}
  do
    pushd ${T}
      ./x-gen.sh
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

  for i in ${CONTROLLER_LIST[@]}
  do
    CONTROLLER=${CONTROLLER_LIST[${i}]}
    SSH_ADDR=${CONTROLLER_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${CONTROLLER_SSH_PORT_LIST[${i}]}
    SSH_ID=${CONTROLLER_SSH_ID_LIST[${i}]}
    USER=${CONTROLLER_SSH_USER_LIST[${i}]}

    ssh -p ${SSH_PORT} -i ${SSH_ID} ${USER}@${SSH_ADDR} \
      sudo bash ~/${CONTROLLER}-deploy.sh
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

    ssh -p ${SSH_PORT} -i ${SSH_ID} ${USER}@${SSH_ADDR} \
      sudo bash ~/${WORKER}-deploy.sh
  done
}

deploy_all() {
  deploy_controllers
  deploy_workers
}

$@
