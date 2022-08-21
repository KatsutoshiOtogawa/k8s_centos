#! /bin/bash

yum update -y

yum install -y yum-plugin-versionlock

# centos7系系に今後/usr/binにnvimが追追される事事無いので直接追加。
curl -fsSL https://github.com/neovim/neovim/releases/download/v0.7.2/nvim-linux64.tar.gz | \
    gunzip | \
    tar x --strip-components=1 -C /usr/
yum install -y nmap
yum install -y mlocate

# kubernetes is neeed to swap off
# disable swap
swapoff -a
# swapdisk時代をコメントアウトしておくと、使われなくなる。
# [](https://docs.oracle.com/cd/F33069_01/start/swap.html)

cat << END >> /etc/systemd/system/swapoff.service
[Unit]
Description=swapoff for k8s running.
After=network-online.target

[Service]
User=root
ExecStart=/usr/sbin/swapoff

[Install]
WantedBy=multi-user.target
END

systemctl enable swapoff.service

# install dependency on crio
yum install -y \
    zstd \
    curl \
    gnupg

OS=CentOS_7
VERSION=1.23
curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable.repo https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/$OS/devel:kubic:libcontainers:stable.repo
curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable:cri-o:$VERSION.repo https://download.opensuse.org/repositories/devel:kubic:libcontainers:stable:cri-o:$VERSION/$OS/devel:kubic:libcontainers:stable:cri-o:$VERSION.repo
yum -y install cri-o cri-tools container-selinux

cat > /etc/modules-load.d/crio.conf <<EOF
# module load for crio
overlay
br_netfilter
EOF

# ここの後の処処のため、即即実行
modprobe br_netfilter

# persistent parameter.
cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system

systemctl daemon-reload
systemctl enable crio
systemctl start crio

# install k8s dependency
yum install -y \
    ebtables \
    ethtool

# el8以以が無いのでel7
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

# Set SELinux in permissive mode (effectively disabling it)
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
yum versionlock add kubelet kubeadm kubectl 

systemctl enable kubelet
systemctl start kubelet

yum -y install iproute-tc
# # yum -y install kubernetes-node

# localhostをadmin, master, workerとして実行
# /etc/kubernetes/admin.confなどを作作すす。
kubeadm init

# defaultはvagrant
user=$(cat /etc/passwd | awk -F: '{if($3==1000){print $1}}')

mkdir /home/${user}/.kube
cp /etc/kubernetes/admin.conf /home/${user}/.kube/config
chown ${user}:${user} /home/${user}/.kube/config

# 設設用のimageをダウンロード
kubeadm config images pull

yum install -y podman

updatedb
