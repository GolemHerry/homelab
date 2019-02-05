# Kube Installation

No `Ansible`, just plain shell scripts

## Table of Contents

- [Prerequisite](#prerequisite)
    - [Serverside](#serverside)
    - [Localhost](#localhost)
- [General steps](#general-steps)
- [How to use](#how-to-use)
    - [First time deployment](#first-time-deployment)
    - [Configuration Update](#configuration-update)
    - [Software Update](#kubernetes-update)
    - [Provisioning new kubernetes workers (after first time deployment)](#provisioning-new-kubernetes-workers)
- [Services](#services)
    - [Fundamental Services](#fundamental-services)
    - [Extra Services with `helm`](#extra-services-with-helm)
        - [Install `helm`](#install-helm)
        - [Monitoring Service](#monitoring-service)
    - [Gitlab](#gitlab)
      - [GitLab - Runner](#gitlab-runner)
- [Service Mesh](#service-mesh)
    - [Install `istio` via helm](#install-istio-via-helm)
    - [Deploy demo service mesh app `bookinfo`](#deploy-demo-service-mesh-app-bookinfo)
- [Ingress with `ingress-nginx`](#ingress)
- [References](#references)

## Prerequisite

Please make sure

1. Your DNS-Server (maybe integrated in you router) do not resolve your server hostname to ipv6 address, since we don't tend to ipv6 routes between servers
2. Your DNS-Server (maybe integrated in you router) resolve your server hostname to ipv4 address, or there can be some issues when deploying services

### Serverside

- System
    - Ubuntu 18.04
- Software
    - ssh, scp (with public-key installed)

### Localhost

- [`cfssl`](https://github.com/cloudflare/cfssl#installation)
- [`kubectl`](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [`helm`](https://github.com/helm/helm#install) (optional, if you want to deploy services via `helm`)
- [`istioctl`]() (optional, if you want to deploy service mesh demo app)

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

### Software Update

1. Edit `env.sh` with your favourite editor, then download and redeploy all files to your servers

```bash
$ ./x-helper.sh download_all && ./x-helper.sh prepare_bin_all
$ ./x-helper.sh upload_all && ./x-helper.sh deploy_all
```

### Provisioning new kubernetes workers

In case you want to extend your cluster with more kubernetes workers and without any data loss or service interrupton after the first time deployment, we provide the following method

__NOTE:__ Assuming you are at `/path/to/homelab/kube`

1.Start with a copied project

```bash
$ cd ../..
$ cp -a homelab homelab-new
$ cd homelab-new/kube
```

2.Config `env.sh` for your new workers (keep controllers config as is)

3.Generate worker configurations and deploy to new workers

```bash
$ ./x-helper.sh gen_worker_all && ./x-helper.sh upload_worker_all
$ ./x-helper.sh deploy_worker_all
```

## Services

### Fundamental Services

1.Install kube-dns (coredns)

```bash
$ kubectl create -f services/kube-coredns
```

2.Create certs for metrics-server and deploy metrics-server

```bash
$ kubectl create secret generic \
    -n kube-system metrics-server-secrets \
    --from-file=ca=common/generated/ca-aggregator.pem \
    --from-file=ms-key=common/generated/aggregator-proxy-client-key.pem \
    --from-file=ms-cert=common/generated/aggregator-proxy-client.pem
$ kubectl create -f services/metrics-server/deploy/1.8+

# In China, you can use aliyun google container mirror (configured, maybe not the latest)
# $ kubectl create -f services/metrics-server-cn
```

3.Install kubernetes-dashboard (optional)

```bash
$ kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml

# In China, you can use aliyun google container mirror
# $ kubectl create -f services/kube-dashboard/kube-dashboard.cn.yaml

# (optional, not recommended if you are using public servers)
# skip dashborad authentication (click `skip` on dashboard login page)
# $ kubectl create -f services/kube-dashboard/dashoard-admin.yaml
```

### Extra Services with `helm`

- [Monitoring Service](#monitoring-service)

#### Install `helm`

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

#### Monitoring Service

##### Install `Prometheus` via `helm` (non-persistent)

```bash
# modify services/prometheus/values.yaml if you want to persist metrics data or other features
$ helm install --namespace monitoring --name prometheus stable/prometheus -f services/prometheus/values.yaml
```

##### Install `Grafana` via `helm`

1.Install grafana to your kubernetes cluster

```bash
# modify services/grafana/values.yaml if necessary
$ helm install --namespace monitoring --name grafana stable/grafana -f services/grafana/values.yaml
```

2.Access your grafana

```bash
$ export POD_NAME=$(kubectl get pods -n monitoring -l "app=grafana" -o jsonpath="{.items[0].metadata.name}")
$ kubectl --namespace monitoring port-forward ${POD_NAME} 3000

# get admin password (for admin user)
$ kubectl --namespace monitoring get secret grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

# open up your browser and navigate to http://localhost:3000
```

3.Configure your dashboard

### GitLab

1.Add `gitlab` helm chart repo and update

```bash
helm repo add gitlab https://charts.gitlab.io/ && helm repo update
```

2.Install `gitlab` with helm ([see - all options](https://gitlab.com/charts/gitlab/blob/master/doc/installation/command-line-options.md))

```bash
helm upgrade --install gitlab gitlab/gitlab \
  --timeout 600 \
  --set global.hosts.domain= \
  --set global.hosts.externalIP= \
  --set certmanager-issuer.email=
```

#### GitLab Runner

<!-- TODO -->

## Service Mesh

### Install `istio` via helm

__REFERENCE:__ [istio - install/kubernetes/helm/istio](https://github.com/istio/istio/tree/master/install/kubernetes/helm/istio)

1.Create namespace for `Istio`

```bash
$ kubectl create ns istio-system
```

3.Install `Istio` with automatic sidecar injection

```bash
$ helm install services/istio/install/kubernetes/helm/istio --name istio --namespace istio-system
# wait for a while, this could take some time

# Again, In China, you can use docker mirror to install istio
# $ helm install services/istio-cn --name istio --namespace istio-system

# uninstalling
# $ helm del --purge istio
# $ kubectl -n istio-system delete crd --all
```

### Deploy demo service mesh app `bookinfo`

1.Create `demo` namespace for management ease

```bash
$ kubectl create namespace demo
```

2.Label `demo` namespace for automatic istio sidecar injection

```bash
$ kubectl label namespaces demo istio-injection=enabled
```

3.Deploy `bookinfo` demo app to `demo` namespace

```bash
$ kubectl -n demo apply -f services/istio/samples/bookinfo/platform/kube/bookinfo.yaml

# wait for a while, this could take some time
```

4.Create gateway for `bookinfo` app

```bash
$ kubectl -n demo apply -f services/istio/samples/bookinfo/networking/bookinfo-gateway.yaml
```

5.Access to `bookinfo` app via one of `istio-ingress-gateway`

```bash
$ export POD_NAME=$(kubectl get po -l istio=ingressgateway -n istio-system -o 'jsonpath={.items[0].metadata.name}')
$ kubectl -n istio-system port-forward ${POD_NAME} 8080:80

# check app working
# open up your browser and navigate to http://127.0.0.1:8080/productpage
# or use curl to check http status code
# $ curl -o /dev/null -s -w "%{http_code}\n" http://127.0.0.1:8080/productpage
# should give you output `200`
```

6.Change `bookinfo` routing

```bash
$ kubectl -n demo apply -f services/istio/samples/bookinfo/networking/destination-rule-all.yaml
# refresh page and you will find differences!
```

## Ingress

We will setup ingress with `ingress-nginx` and `envoy` for remote service access

1.Deploy `nginx-ingress` to your `Kubernetes` cluster

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/mandatory.yaml
```

2.Deploy `NodePort` to your cluster, since we are using bare-metal

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/provider/baremetal/service-nodeport.yaml
```

## References

- [Creating a Custom Cluster from Scratch](https://kubernetes.io/docs/setup/scratch)
- [kelseyhightower/kubernetes-the-hard-way](https://github.com/kelseyhightower/kubernetes-the-hard-way)
- [Troubleshooting Kubernetes Networking Issues](https://gravitational.com/blog/troubleshooting-kubernetes-networking/)
- [Configure RBAC In Your Kubernetes Cluster](https://docs.bitnami.com/kubernetes/how-to/configure-rbac-in-your-kubernetes-cluster/)
- [Control Ingress Traffic](https://istio.io/docs/tasks/traffic-management/ingress)
- [Bookinfo Application](https://istio.io/docs/examples/bookinfo/)
- [GitLab Helm Chart](https://docs.gitlab.com/ee/install/kubernetes/gitlab_chart.html)
- [GitLab Runner Helm Chart](https://docs.gitlab.com/ee/install/kubernetes/gitlab_runner_chart.html)