FROM envoyproxy/envoy-alpine:latest

# this Dockerfile will be used in `build` dir
# copy cert and key
COPY ./cert.pem /data/cert/server.crt
COPY ./key.pem /data/cert/server.key

COPY envoy.yaml /etc/envoy/envoy.yaml
