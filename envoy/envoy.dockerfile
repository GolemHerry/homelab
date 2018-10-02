FROM envoyproxy/envoy-alpine:latest

# this Dockerfile will be used in `build` dir
# copy cert and key
COPY ./cert.pem /etc/server.crt
COPY ./key.pem /etc/server.key

COPY envoy.yaml /etc/envoy/envoy.yaml