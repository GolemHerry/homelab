#!/bin/bash

set -e

source ../env

mkdir -p \
    /data/grafana/config/provisioning \
    /data/grafana/data \
    /data/grafana/log \
    /data/grafana/plugins

docker run \
  -d \
  -p ${LISTEN_PORT}:3000 \
  --name=monitor \
  -v /data/grafana/config/provisioning:/etc/grafana/provisioning \
  -v /data/grafana/data:/var/lib/grafana \
  -v /data/grafana/log:/var/log/grafana \
  -v /data/grafana/plugins:/var/lib/grafana/plugins \
  -e "GF_SERVER_ROOT_URL=${SERVER_URL}" \
  -e "GF_SECURITY_ADMIN_PASSWORD=${ADMIN_PASSWD}" \
  -e "GF_DATABASE_PASSWORD=${DB_PASSWD}" \
  homelab-grafana:latest
