# Homelab (WIP)

My Homelab (with Kubernetes inside)

## Components

- Infrastructure (used by components if required)
    - postgres (singleton)
    - redis (singleton)
- Envoy Proxy (serve as edge proxy)
- Grafana (monitoring)
- (WIP) Kubernetes (with `istio`, `gVisor`) and application services
    - Nextcloud
    - Prometheus
    - GitLab (with CI)

## Setup

### Network topology

![topology](./art/network/topology.svg)

### Prerequisite

<details>
<summary>0. Get this project using git (include submodules)</summary>
<pre><code class="language-bash">git clone --recurse-submodules https://github.com/jeffreystoke/homelab.git</code></pre>
</details>

<details>
<summary>1. A cheap server/laptop/PC with hypervisor (e.g. ESXI, XEN, ...) installed or serval bare-metal servers</summary>
I got the second-hand DELL R710 rack server at about $200, and installed ESXI 6.7 on it
<br/><br/>
Useful Tutorial for ESXI Installation: <a href="https://www.virten.net/2014/12/howto-create-a-bootable-esxi-installer-usb-flash-drive/">Create a Bootable ESXi Installer USB Flash Drive</a>
<br/>
</details>

<details>
<summary>2. A firewall redirecting all ingress traffic to the <code>envoy</code> proxy</summary>
I used a <a href="https://openwrt.org/"><code>OpenWRT</code></a> router (awesome and stable) and configured internal firewall with
<pre>
<code class="language-uci">config redirect
        option target 'DNAT'
        option src 'wan'
        option dest 'lan'
        option proto 'tcp'
        option src_dport '443'
        option dest_ip '10.0.0.254'
        option dest_port '10000'
        option name 'envoy-proxy'</code>
</pre>
</details>

<details>
<summary>3. X509 Certifications for edge-proxy <code>https</code></summary>
It's 2018, always use tls when talking through the Internet! I made it with the help of <a href="https://github.com/FiloSottile/mkcert"><code>mkcert</code></a>, a great tool for creating self signed certifications

You have to run the following command inside the porject root directory
<pre>
<code class="language-bash"># install local CA
mkcert -install
# replace example.com with your own domain name
mkcert '*.example.com'
# move your certification and key to cert dir
mkdir -p cert && mv *-key.pem cert/key.pem && mv *.pem cert/cert.pem</code>
</pre>
</details>

### Steps

<details>
<summary>1. Setup your <code>Kubernetes</code> cluster with <a href="./kube"><code>kube</code></a></summary>
<pre>
<code class="language-bash">cd kube</code>
</pre>
</details>
