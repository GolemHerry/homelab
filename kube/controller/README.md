# Kubernetes Controller

## Prerequisite

- Etcd services

## Componenets

- kube-apiserver
    - related files
        - kube-ca-cert.pem, kube-ca-key.pem
        - kube-api-cert.pem, kube-api-key.pem
        - kube-service-account-cert.pem, kube-service-account-key.pem
        - encryption-config.yaml
        - kube-api.service
- kube-controller-manager
    - related files
        - kube-controller-manager.kubeconfig
        - kube-controller-manager.service
- kube-scheduler
    - related files
        - kube-scheduler.kubeconfig
        - kube-scheduler.yaml
        - kube-scheduler.service
