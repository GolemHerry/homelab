# Kube Installation

1. Running as system daemon
    - kubelet
    - kube-proxy
2. Running as containers
    - etcd
    - kube-apiserver
    - kube-controller-manager
    - kube-scheduler

## General steps

1. Design network and create virtual/bare-metal servers
2. Generate ca and cert/key pair for `etcd` and `kubernetes` components
3. Install and start `etcd` services
4. Install `kubernetes` [controller](./controller) components on some of your servers, and configure
5. Install `kubernetes` [worker](./worker) components on some of your servers, and configure
6. Configure network and deploy

__Notice:__ I will create one virtual server serving both `etcd` and `kubernetes` controller, and three virtual servers serving as `kubernetes` worker

## References

- [Creating a Custom Cluster from Scratch](https://kubernetes.io/docs/setup/scratch)
- [kelseyhightower/kubernetes-the-hard-way](https://github.com/kelseyhightower/kubernetes-the-hard-way)
