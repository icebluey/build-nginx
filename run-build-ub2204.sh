#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ
umask 022
set -e
systemctl start docker
sleep 5
docker run --cpus="2.0" --rm --name ub2204 -itd ubuntu:22.04 bash
sleep 2
docker exec ub2204 apt update -y
#docker exec ub2204 apt upgrade -fy
docker exec ub2204 apt install -y bash vim wget ca-certificates curl
docker exec ub2204 /bin/ln -svf bash /bin/sh
docker exec ub2204 /bin/bash -c '/bin/rm -fr /tmp/*'
docker cp ub2204 ub2204:/home/
docker exec ub2204 /bin/bash /home/ub2204/.preinstall_ub2204
docker exec ub2204 /bin/bash /home/ub2204/build-nginx.sh
_nginx_ver="$(docker exec ub2204 ls -1 /tmp/ | grep -i '^nginx.*xz$' | sed -e 's|nginx-||g' -e 's|-[0-1]_.*||g')"
rm -fr /home/.tmp
mkdir /home/.tmp
docker cp ub2204:/tmp/nginx-"${_nginx_ver}"-1_ub2204_amd64.tar.xz /home/.tmp/
docker cp ub2204:/tmp/nginx-"${_nginx_ver}"-1_ub2204_amd64.tar.xz.sha256 /home/.tmp/
exit
