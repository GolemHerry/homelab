#!/bin/bash

set -e

docker run -d -p 10000:10000 --name homelab-envoy:latest
