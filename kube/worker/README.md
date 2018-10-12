# Worker

Worker related

## Generated File list

- kubelet
    - related files
        - ${WORKER_NAME}.pem, ${WORKER_NAME}-key.pem
            - ${WORKER_NAME}.kubeconfig
        - ${WORKER_NAME}-kubelet.yaml
        - kubelet.service
- containerd
    - related files
        - containerd.config.toml
        - containerd.service
- crictl.yaml
- cni-loopback.json
- ${WORKER_NAME}-cni-bridge.json
- ${WORKER_NAME}-network.yaml
- ${WORKER_NAME}-deploy.sh
