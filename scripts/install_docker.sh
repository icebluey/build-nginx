#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ
umask 022
/bin/systemctl daemon-reload >/dev/null 2>&1 || :
systemctl stop docker.service >/dev/null 2>&1 || :
systemctl stop docker.socket >/dev/null 2>&1 || :
systemctl stop containerd.service >/dev/null 2>&1 || :
systemctl disable docker.service >/dev/null 2>&1 || :
systemctl disable docker.socket >/dev/null 2>&1 || :
systemctl disable containerd.service >/dev/null 2>&1 || :
/bin/rm -fr /root/.docker
/bin/rm -fr ~/.docker
set -e
_tmp_dir="$(mktemp -d)"
cd "${_tmp_dir}"
wget -q -c -t 9 -T 9 \
"https://github.com/icebluey/docker/releases/download/v2024-09-15/containerd-1.7.22-1_amd64.tar.xz"
wget -q -c -t 9 -T 9 \
"https://github.com/icebluey/docker/releases/download/v2024-09-15/docker-only-27.2.1-1_amd64.tar.xz"
rm -f /usr/bin/containerd
rm -fr /usr/bin/containerd-*
rm -f /usr/bin/ctr
rm -f /usr/bin/docker
rm -f /usr/bin/dockerd
rm -f /usr/bin/dockerd-rootless-setuptool.sh
rm -f /usr/bin/dockerd-rootless.sh
rm -f /usr/bin/docker-init
rm -f /usr/bin/docker-proxy
rm -f /usr/bin/rootlesskit
rm -f /usr/bin/rootlesskit-docker-proxy
rm -f /usr/bin/runc
rm -f /usr/bin/vpnkit
rm -f /usr/bin/docker-compose
rm -fr /usr/lib/systemd/system/containerd.service
rm -fr /usr/lib/systemd/system/docker.*
rm -fr /lib/systemd/system/containerd.service
rm -fr /lib/systemd/system/docker.*
rm -fr /var/lib/docker-engine
rm -fr /var/lib/docker
rm -fr /var/lib/containerd
rm -fr /opt/containerd
rm -fr /run/containerd
rm -fr /run/docker*
rm -fr /var/run/containerd
rm -fr /var/run/docker*
rm -fr /etc/containerd
rm -fr /etc/docker
rm -fr /etc/systemd/system/docker.service.d
rm -fr /usr/libexec/docker
userdel -f -r docker 2>/dev/null || :
groupdel -f docker 2>/dev/null || :
ip link set docker0 down 2>/dev/null
sleep 1
ip link delete docker0 2>/dev/null
/bin/systemctl daemon-reload >/dev/null 2>&1 || :
tar -xof docker*.tar* -C /
tar -xof containerd*.tar* -C /
cd /tmp
rm -fr "${_tmp_dir}"
bash /etc/containerd/.install.txt
bash /etc/docker/.install.txt
exit
