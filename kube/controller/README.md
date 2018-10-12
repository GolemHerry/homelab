# Controller

Controller related

## Generated File list

- kube-apiserver
    - related files
        - kubernetes.pem, kubernetes-key.pem
        - kube-service-account.pem, kube-service-account-key.pem
            - kube-service-account.kubeconfig
        - encryption-config.yaml (currently not used)
        - ${CTRL_NAME}-kube-apiserver.service
- kube-controller-manager
    - related files
        - kube-controller-manager.pem, kube-controller-manager-key.pem
            - kube-controller-manager.kubeconfig
        - kube-controller-manager.service
- kube-scheduler
    - related files
        - kube-scheduler.pem, kube-scheduler-key.pem
            - kube-scheduler.kubeconfig
        - kube-scheduler.yaml
        - kube-scheduler.service
- healthcheck.nginx
- ${CTRL_NAME}-network.yaml
- ${CTRL_NAME}.etcd.service
- ${CTRL_NAME}-deploy.sh
