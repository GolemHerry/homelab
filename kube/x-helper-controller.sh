#!/bin/bash

CTRL_DIR=controller

source env.sh
source base.sh

gen_ctrl_cert() {
  pushd ${CTRL_DIR}
    ./x-gen.sh gen_cert
  popd
}

gen_ctrl_conf() {
  pushd ${CTRL_DIR}
    ./x-gen.sh gen_conf
  popd
}

gen_ctrl_all() {
  gen_ctrl_cert
  gen_ctrl_conf
}

download_ctrl_bin() {
  pushd ${CTRL_DIR}
    ./x-get.sh
  popd
}

prepare_ctrl_bin() {
  pushd ${CTRL_DIR}
    ./x-upload.sh prepare_bin
  popd
}

upload_ctrl_cert() {
  pushd ${CTRL_DIR}
    ./x-upload.sh upload_cert
  popd
}

upload_ctrl_conf() {
  pushd ${CTRL_DIR}
    ./x-upload.sh upload_conf
  popd
}

upload_ctrl_bin() {
  pushd ${CTRL_DIR}
    ./x-upload.sh upload_bin
  popd
}

upload_ctrl_all() {
  upload_ctrl_cert
  upload_ctrl_conf
  upload_ctrl_bin
}

deploy_ctrl() {
  for i in ${!CTRL_LIST[@]}
  do
    CTRL=${CTRL_LIST[${i}]}
    SSH_ADDR=${CTRL_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${CTRL_SSH_PORT_LIST[${i}]}
    SSH_ID=${CTRL_SSH_ID_LIST[${i}]}
    USER=${CTRL_SSH_USER_LIST[${i}]}
    PASS=${CTRL_SSH_USER_PASS_LIST[${i}]}

    echo "[DEPLOY] ${CTRL}"
    ssh -p ${SSH_PORT} -i ${SSH_ID} ${USER}@${SSH_ADDR} \
      "echo ${PASS} | sudo -S bash ~/${CTRL}-deploy.sh $1" &
  done
  wait
}

deploy_ctrl_cert() {
  deploy_ctrl deploy_cert
}

deploy_ctrl_conf() {
  deploy_ctrl deploy_conf
}

deploy_ctrl_bin() {
  deploy_ctrl deploy_bin
}

deploy_ctrl_all() {
  deploy_ctrl deploy_all
}

reboot_ctrl() {
  for i in ${!CTRL_LIST[@]}
  do
    CTRL=${CTRL_LIST[${i}]}
    SSH_ADDR=${CTRL_EXTERN_IP_LIST[${i}]}
    SSH_PORT=${CTRL_SSH_PORT_LIST[${i}]}
    SSH_ID=${CTRL_SSH_ID_LIST[${i}]}
    USER=${CTRL_SSH_USER_LIST[${i}]}
    PASS=${CTRL_SSH_USER_PASS_LIST[${i}]}

    echo "[REBOOT] ${CTRL}"
    ssh -p ${SSH_PORT} -i ${SSH_ID} ${USER}@${SSH_ADDR} \
      "echo ${PASS} | sudo -S reboot" &
  done
  wait
}