FROM grafana/grafana:latest

# this Dockerfile will be used in `build` dir
# copy cert and key
COPY ./cert.pem /etc/server.crt
COPY ./key.pem /etc/server.key

COPY grafana.ini /etc/grafana/grafana.ini
