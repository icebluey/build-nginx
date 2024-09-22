#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ
umask 022
apt update -y -qqq
/bin/rm -fr /etc/resolv.conf
echo "nameserver 8.8.8.8" >/etc/resolv.conf
apt install -y chrony
systemctl stop chrony.service
sed -e "/^pool/d" -i /etc/chrony/chrony.conf
sed -e "/^server/d" -i /etc/chrony/chrony.conf
sed -e "s|^refclock|#refclock|g" -i /etc/chrony/chrony.conf
sed -e "1iserver time1.google.com iburst minpoll 4 maxpoll 5\nserver time2.google.com iburst minpoll 4 maxpoll 5\nserver time3.google.com iburst minpoll 4 maxpoll 5\nserver time4.google.com iburst minpoll 4 maxpoll 5" -i /etc/chrony/chrony.conf
systemctl start chrony.service
systemctl enable chrony.service
sleep 10
chronyc makestep
apt install -y binutils coreutils util-linux findutils diffutils pkg-config
apt install -y systemd passwd patch sed gawk grep file tar gzip bzip2 xz-utils
apt install -y socat ethtool ipvsadm ipset psmisc bash-completion conntrack iproute2 nfs-common
apt install -y daemon procps net-tools
apt install -y iptables
apt install -y ebtables
apt install -y nftables
apt install -y libseccomp-dev libseccomp2 gperf

exit
