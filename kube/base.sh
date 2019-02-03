#!/bin/bash

set -e

# 
# 
# DO NOT Edit Variables Below, Unless You Know What You Are Doing
# 
# 

export GEN_DIR="generated"
export DOWNLOAD_DIR="download"

export WORKER_ADDR_LIST=""
export CTRL_ADDR_LIST""
export ETCD_INITIAL_CLUSTERS=""
export ETCD_SERVERS=""

for i in ${!WORKER_LIST[@]}
do
  INTERN_IP=${WORKER_INTERN_IP_LIST[${i}]}
  EXTERN_IP=${WORKER_EXTERN_IP_LIST[${i}]}
  POD_CIDR=${WORKER_POD_CIDR_LIST[$i]}

  export WORKER_ADDR_LIST="${INTERN_IP},${EXTERN_IP},${WORKER_ADDR_LIST}"
done

for i in ${!CTRL_INTERN_IP_LIST[@]}
do
  INTERN_IP=${CTRL_INTERN_IP_LIST[${i}]}
  EXTERN_IP=${CTRL_EXTERN_IP_LIST[${i}]}

  export CTRL_ADDR_LIST="${INTERN_IP},${EXTERN_IP},${CTRL_ADDR_LIST}"
done

for i in ${!CTRL_LIST[@]}
do
  CONTROLLER=${CTRL_LIST[${i}]}
  INTERN_IP=${CTRL_INTERN_IP_LIST[${i}]}
  URL="https://${INTERN_IP}:${KUBE_ETCD_LISTEN_PEER_PORT}"

  if [[ -n "${ETCD_INITIAL_CLUSTERS}" ]]; then
    export ETCD_INITIAL_CLUSTERS="etcd-${CONTROLLER}=${URL},${ETCD_INITIAL_CLUSTERS}"
  else
    export ETCD_INITIAL_CLUSTERS="etcd-${CONTROLLER}=${URL}"
  fi

  if [[ -n "${ETCD_SERVERS}" ]]; then
    export ETCD_SERVERS="https://${INTERN_IP}:${KUBE_ETCD_LISTEN_CLIENT_PORT},${ETCD_SERVERS}"
  else
    export ETCD_SERVERS="https://${INTERN_IP}:${KUBE_ETCD_LISTEN_CLIENT_PORT}"
  fi
done

