# Kube Installation

No `Ansible`, just plain shell scripts

## Prerequisite

Please make sure

1. Your router do not resolve your server hostname to ipv6 address, since we don't tend to ipv6 routes between servers
2. Your router resolve your server hostname to ipv4 address, or there can be some issues when deploying services

### Serverside

- System
    - ubuntu 18.04
- Software
    - ssh, scp (with public-key installed)

### Localhost

- [`cfssl`](https://github.com/cloudflare/cfssl#installation)
- [`kubectl`](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [`helm`](https://github.com/helm/helm#install) (optional, if you want to deploy services via `helm`)

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

2.Download all software required and prepare them for uploading

```bash
$ ./x-helper.sh download_all && ./x-helper.sh prepare_bin_all
```

3.Upload all required files to your server, then deploy them

```bash
$ ./x-helper.sh upload_all && ./x-helper.sh deploy_all
```

4.Config local `kubectl`

```bash
$ ./x-helper.sh config_local_kubectl
```

### Configuration Update

1. Edit `env.sh` with your favourite editor, then generate, upload configurations to your servers and deploy

```bash
$ ./x-helper.sh update_conf
```

### Kubernetes Update

1. Edit `env.sh` with your favourite editor, then download and redeploy all files to your servers

```bash
$ ./x-helper.sh download_all && ./x-helper.sh prepare_bin_all
$ ./x-helper.sh upload_all && ./x-helper.sh deploy_all
```

### Services

#### Fundamental Services

1.Install kube-dns (coredns)

```bash
$ kubectl create -f services/kube-coredns
```

2.Create certs for metrics-server and install

```bash
$ kubectl create secret generic \
    -n kube-system metrics-server-secrets \
    --from-file=ca=common/generated/ca-aggregator.pem \
    --from-file=ms-key=common/generated/aggregator-proxy-client-key.pem \
    --from-file=ms-cert=common/generated/aggregator-proxy-client.pem
$ kubectl create -f services/kube-metric-server
```

3.Install kube-dashboard

```bash
$ kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml

# in China, you can use aliyun google container mirror
# $ kubectl create -f services/kube-dashboard/kube-dashboard.cn.yaml

# (optional, not recommended)
# skip dashborad authentication (click `skip` on dashboard login page)
# $ kubectl create -f services/kube-dashboard/dashoard-admin.yaml
```

#### Configure `helm`

1.Create and bind the tiller service account for `helm`

```bash
$ kubectl create -f services/helm/tiller-cluster-role.yaml
```

2.Init `helm` with tiller service account

```bash
$ helm init --service-account tiller --upgrade

# In China, you can use aliyun google container mirror to get tiller
# $ helm init --service-account tiller --upgrade -i registry.cn-hangzhou.aliyuncs.com/google_containers/tiller:v2.11.0
```

#### Further

// TODO: add services via `helm`

## References

- [Creating a Custom Cluster from Scratch](https://kubernetes.io/docs/setup/scratch)
- [kelseyhightower/kubernetes-the-hard-way](https://github.com/kelseyhightower/kubernetes-the-hard-way)
- [Troubleshooting Kubernetes Networking Issues](https://gravitational.com/blog/troubleshooting-kubernetes-networking/)
- [Configure RBAC In Your Kubernetes Cluster](https://docs.bitnami.com/kubernetes/how-to/configure-rbac-in-your-kubernetes-cluster/)
