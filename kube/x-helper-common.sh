#!/bin/bash

COMMON_DIR=common

source env.sh
source base.sh

gen_common_cert() {
  pushd ${COMMON_DIR}
    ./x-gen.sh gen_cert
  popd
}

gen_common_conf() {
  pushd ${COMMON_DIR}
    ./x-gen.sh gen_conf
  popd
}

gen_common_all() {
  gen_common_cert
  gen_common_conf
}

download_common_bin() {
  pushd ${COMMON_DIR}
    ./x-get.sh
  popd
}

prepare_common_bin() {
  pushd ${COMMON_DIR}
    ./x-upload.sh prepare_bin
  popd
}

upload_common_cert() {
  pushd ${COMMON_DIR}
    ./x-upload.sh upload_cert
  popd
}

upload_common_conf() {
  pushd ${COMMON_DIR}
    ./x-upload.sh upload_conf
  popd
}

upload_common_bin() {
  pushd ${COMMON_DIR}
    ./x-upload.sh upload_bin
  popd
}

upload_common_all() {
  upload_common_cert
  upload_common_conf
  upload_common_bin
}