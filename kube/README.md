# Kube Installation

No `Ansible`, just plain shell scripts

## Prerequisite

### Serverside

- ssh, scp (public-key installed)

### Localhost

## General steps

1. Design your network and create virtual/bare-metal servers
2. Generate ca and cert/key pair for `etcd` and `kubernetes` components
3. Install and start `etcd` services
4. Install `kubernetes` [controller](./controller) components on some of your servers, and configure
5. Install `kubernetes` [worker](./worker) components on some of your servers, and configure
6. Configure network and deploy

## How to use

### First time deployment

0.Copy and modify `env.sh` according to your homelab

```bash
$ cp env.template.sh env.sh
# edit `env.sh` with your favourite editor
```

1.Generate CA, certificates and kubeconfig

```bash
$ ./x-helper.sh gen_ca && ./x-helper.sh gen_all
```

2.Download all software required

```bash
$ ./x-helper.sh download_all
```

3.Prepare all required software to upload to your server

```bash
$ ./x-helper.sh prepare_bin_all
```

4.Upload all required files to your server

```bash
$ ./x-helper.sh upload_all
```

5.Deploy `Kubernetes` to your server

```bash
$ ./x-helper.sh deploy_all
```

6.Config local `kubectl`

```bash
$ ./x-helper.sh config_local_kubectl
```

### Configuration Update

1. Edit `env.sh` with your favourite editor, then generate, upload configurations to your servers and deploy

```bash
$ ./x-helper.sh update_conf
```

__NOTE:__ these steps won't generate new CA, so you don't need to config local `kubectl`

### Network

// TODO

### Services

#### Fundamental Services

1.Install kube-dns (coredns)

```bash
$ kubectl create -f services/kube-coredns
```

2.Install metric-server

```bash
$ kubectl create -f services/kube-metric-server
```

3.Install kube-dashboard

```bash
$ kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml
# in China, you should use aliyun google container mirror
# `kubectl create -f services/kube-dashboard`

# (optional and not recommended)
# skip dashborad authentication (click `skip` on dashboard login page)
# $ kubectl create -f services/kube-dashboard/dashoard-admin.yaml
```

## References

- [Creating a Custom Cluster from Scratch](https://kubernetes.io/docs/setup/scratch)
- [kelseyhightower/kubernetes-the-hard-way](https://github.com/kelseyhightower/kubernetes-the-hard-way)
- [Troubleshooting Kubernetes Networking Issues](https://gravitational.com/blog/troubleshooting-kubernetes-networking/)