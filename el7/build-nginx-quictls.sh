#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ

umask 022

CFLAGS='-O2 -fexceptions -g -grecord-gcc-switches -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -fstack-protector-strong -m64 -mtune=generic -fasynchronous-unwind-tables -fstack-clash-protection -fcf-protection'
export CFLAGS
CXXFLAGS='-O2 -fexceptions -g -grecord-gcc-switches -pipe -Wall -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -Wp,-D_GLIBCXX_ASSERTIONS -fstack-protector-strong -m64 -mtune=generic -fasynchronous-unwind-tables -fstack-clash-protection -fcf-protection'
export CXXFLAGS
LDFLAGS='-Wl,-z,relro -Wl,--as-needed -Wl,-z,now'
export LDFLAGS
_ORIG_LDFLAGS="${LDFLAGS}"

CC=gcc
export CC
CXX=g++
export CXX
/sbin/ldconfig

if ! grep -q -i '^1:.*docker' /proc/1/cgroup; then
    echo
    echo ' Not in a container!'
    echo
    exit 1
fi

yum makecache
yum install -y glibc-devel glibc-headers libxml2-devel libxslt-devel gd-devel perl-devel perl bc

set -e

_dl_nginx() {
    set -e
    # nginx-quic
    wget -c -t 9 -T 9 'https://hg.nginx.org/nginx-quic/archive/quic.tar.gz'
    sleep 1
    tar -xof quic.tar.gz
    sleep 1
    rm -f quic.tar.gz
    mv -f ngin* nginx
    sleep 1
    [[ -e nginx/configure ]] || /bin/cp -f nginx/auto/configure nginx/configure

    # modules
    install -m 0755 -d modules && cd modules
    git clone "https://github.com/nbs-system/naxsi.git" \
      ngx_http_naxsi_module
    git clone "https://github.com/nginx-modules/ngx_cache_purge.git" \
      ngx_http_cache_purge_module
    git clone "https://github.com/arut/nginx-rtmp-module.git" \
      ngx_rtmp_module
    git clone "https://github.com/leev/ngx_http_geoip2_module.git" \
      ngx_http_geoip2_module
    git clone "https://github.com/openresty/headers-more-nginx-module.git" \
      ngx_http_headers_more_filter_module
    git clone "https://github.com/yaoweibin/ngx_http_substitutions_filter_module.git" \
      ngx_http_substitutions_filter_module
    git clone --recursive "https://github.com/eustas/ngx_brotli.git" \
      ngx_http_brotli_module
    git clone "https://github.com/apache/incubator-pagespeed-ngx.git" \
      ngx_pagespeed
      wget -c "https://dl.google.com/dl/page-speed/psol/1.13.35.2-x64.tar.gz" -O psol.tar.gz
      sleep 1
      tar -xof psol.tar.gz -C ngx_pagespeed/
      sleep 1
      rm -fr psol.tar.gz
    git clone "https://github.com/openresty/redis2-nginx-module.git" \
      ngx_http_redis2_module
    git clone "https://github.com/openresty/memc-nginx-module.git" \
      ngx_http_memc_module
    git clone "https://github.com/openresty/echo-nginx-module.git" \
      ngx_http_echo_module
    cd ..

    install -m 0755 -d geoip2 && cd geoip2
    _license_key='uzrU0s2GJt6I'
    for _edition_id in GeoLite2-ASN GeoLite2-Country GeoLite2-City; do
        wget -c -t 9 -T 9 -O "${_edition_id}.tar.gz" "https://download.maxmind.com/app/geoip_download?edition_id=${_edition_id}&license_key=${_license_key}&suffix=tar.gz"
    done
    sleep 1
    ls -1 *.tar* | xargs -I '{}' tar -xof '{}'
    sleep 1
    rm -f *.tar*
    find ./ -mindepth 2 -type f -iname '*.mmdb' | xargs -I '{}' cp -f '{}' ./
    sleep 1
    find ./ -mindepth 1 -type d | xargs -I '{}' rm -fr '{}'
    cd ..
}

_build_zlib() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _zlib_ver="$(wget -qO- 'https://www.zlib.net/' | grep 'zlib-[1-9].*\.tar\.' | sed -e 's|"|\n|g' | grep '^zlib-[1-9]' | sed -e 's|\.tar.*||g' -e 's|zlib-||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://www.zlib.net/zlib-${_zlib_ver}.tar.gz"
    tar -xof zlib-*.tar.*
    sleep 1
    rm -f zlib-*.tar*
    cd zlib-*
    ./configure --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --64
    make all
    rm -fr /tmp/zlib
    make DESTDIR=/tmp/zlib install
    cd /tmp/zlib
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    install -m 0755 -d usr/lib64/nginx/private
    /bin/cp -af usr/lib64/*.so* usr/lib64/nginx/private/
    /bin/rm -f /usr/lib64/libz.so*
    /bin/rm -f /usr/lib64/libz.a
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/zlib
    /sbin/ldconfig
}

_build_xz() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _xz_ver="$(wget -qO- 'https://tukaani.org/xz/' | grep -i 'href="xz-[1-9].*tar\.' | sed 's|"|\n|g' | grep -i '^xz-[1-9].*tar\.' | grep -ivE 'alpha|beta|rc' | sed -e 's|xz-||g' -e 's|\.tar.*||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://tukaani.org/xz/xz-${_xz_ver}.tar.gz"
    tar -xof xz-*.tar*
    sleep 1
    rm -f xz-*.tar*
    cd xz-*
    LDFLAGS='' ; LDFLAGS='-Wl,-z,relro -Wl,--as-needed -Wl,-z,now -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
    # Remove /usr/lib64 in xz runpath
    sed 's|^hardcode_libdir_flag_spec=.*|hardcode_libdir_flag_spec=""|g' -i libtool
    make all
    rm -fr /tmp/xz
    make install DESTDIR=/tmp/xz
    cd /tmp/xz
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    install -m 0755 -d usr/lib64/nginx/private
    cp -af usr/lib64/*.so* usr/lib64/nginx/private/
    rm -f /usr/lib64/liblzma.*
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/xz
    /sbin/ldconfig
}

_build_libxml2() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _libxml2_ver="$(wget -qO- 'https://gitlab.gnome.org/GNOME/libxml2/-/tags' | grep '\.tar\.' | sed 's|"|\n|g' | grep -i '^/GNOME/libxml2/.*/libxml2-.*\.tar\..*' | grep -ivE 'alpha|beta|rc[1-9]' | sed -e 's|.*libxml2-v||g' -e 's|\.tar.*||g' | grep '^[1-9]' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://download.gnome.org/sources/libxml2/${_libxml2_ver%.*}/libxml2-${_libxml2_ver}.tar.xz"
    tar -xof libxml2-*.tar.*
    sleep 1
    rm -f libxml2-*.tar*
    cd libxml2-*
    find doc -type f -executable -print -exec chmod 0644 {} ';'
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --with-legacy --with-ftp --with-xptr-locs --without-python \
    --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
    sed 's|^hardcode_libdir_flag_spec=.*|hardcode_libdir_flag_spec=""|g' -i libtool
    make all
    rm -fr /tmp/libxml2
    make install DESTDIR=/tmp/libxml2
    cd /tmp/libxml2
    # multiarch crazyness on timestamp differences or Makefile/binaries for examples
    touch -m --reference=usr/include/libxml2/libxml/parser.h usr/bin/xml2-config
    rm -fr usr/share/doc
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    install -m 0755 -d usr/lib64/nginx/private
    /bin/cp -af usr/lib64/*.so* usr/lib64/nginx/private/
    rm -f /usr/lib64/libxml2.*
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/libxml2
    /sbin/ldconfig
}

_build_libxslt() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _libxslt_ver="$(wget -qO- 'https://gitlab.gnome.org/GNOME/libxslt/-/tags' | grep '\.tar\.' | sed 's|"|\n|g' | grep -i '^/GNOME/libxslt/.*/libxslt-.*\.tar\..*' | grep -ivE 'alpha|beta|rc[1-9]' | sed -e 's|.*libxslt-v||g' -e 's|\.tar.*||g' | grep '^[1-9]' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 https://download.gnome.org/sources/libxslt/${_libxslt_ver%.*}/libxslt-${_libxslt_ver}.tar.xz
    tar -xof libxslt-${_libxslt_ver}.tar.*
    sleep 1
    rm -f libxslt-*.tar*
    cd libxslt-*
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --without-python --without-crypto \
    --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
    sed 's|^hardcode_libdir_flag_spec=.*|hardcode_libdir_flag_spec=""|g' -i libtool
    make all
    rm -fr /tmp/libxslt
    make install DESTDIR=/tmp/libxslt
    cd /tmp/libxslt
    # multiarch crazyness on timestamp differences or Makefile/binaries for examples
    touch -m --reference=usr/include/libxslt/xslt.h usr/bin/xslt-config
    rm -fr usr/share/doc
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    install -m 0755 -d usr/lib64/nginx/private
    /bin/cp -af usr/lib64/*.so* usr/lib64/nginx/private/
    rm -f /usr/lib64/libxslt.*
    rm -f /usr/lib64/libexslt.*
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/libxslt
    /sbin/ldconfig
}

_build_brotli() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    git clone --recursive 'https://github.com/google/brotli.git' brotli
    sleep 1
    cd brotli
    rm -fr .git
    ./bootstrap
    rm -fr autom4te.cache
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
    make all
    rm -fr /tmp/brotli
    make install DESTDIR=/tmp/brotli
    cd /tmp/brotli
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    install -m 0755 -d usr/lib64/nginx/private
    /bin/cp -af usr/lib64/*.so* usr/lib64/nginx/private/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/brotli
    /sbin/ldconfig
}

_build_libmaxminddb() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    git clone --recursive 'https://github.com/maxmind/libmaxminddb.git' libmaxminddb
    sleep 1
    cd libmaxminddb
    rm -fr .git
    rm -f ltmain.sh
    bash bootstrap
    rm -fr autom4te.cache
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
    make all
    rm -fr /tmp/libmaxminddb
    make install DESTDIR=/tmp/libmaxminddb
    cd /tmp/libmaxminddb
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    install -m 0755 -d usr/lib64/nginx/private
    /bin/cp -af usr/lib64/*.so* usr/lib64/nginx/private/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/libmaxminddb
    /sbin/ldconfig
}

_build_pcre2() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _pcre2_ver="$(wget -qO- 'https://github.com/PCRE2Project/pcre2/releases' | grep -i 'pcre2-[1-9]' | sed 's|"|\n|g' | grep -i '^/PCRE2Project/pcre2/tree' | sed 's|.*/pcre2-||g' | sed 's|\.tar.*||g' | grep -ivE 'alpha|beta|rc' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${_pcre2_ver}/pcre2-${_pcre2_ver}.tar.bz2"
    tar -xof pcre2-*.tar.*
    sleep 1
    rm -f pcre2-*.tar*
    cd pcre2-*
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --enable-pcre2-8 --enable-pcre2-16 --enable-pcre2-32 \
    --enable-jit \
    --enable-pcre2grep-libz --enable-pcre2grep-libbz2 \
    --enable-pcre2test-libedit --enable-unicode \
    --prefix=/usr --libdir=/usr/lib64 --includedir=/usr/include --sysconfdir=/etc
    sed 's|^hardcode_libdir_flag_spec=.*|hardcode_libdir_flag_spec=""|g' -i libtool
    make all
    rm -fr /tmp/pcre2
    make install DESTDIR=/tmp/pcre2
    cd /tmp/pcre2
    rm -fr usr/share/doc/pcre2/html
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    install -m 0755 -d usr/lib64/nginx/private
    /bin/cp -af usr/lib64/*.so* usr/lib64/nginx/private/
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/pcre2
    /sbin/ldconfig
}

_build_openssl30quictls() {
    /sbin/ldconfig
    set -e
    _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _openssl30quictls_ver="$(wget -qO- 'https://github.com/quictls/openssl/branches/all/' | grep -i 'branch="OpenSSL-3\.0\..*quic"' | sed 's/"/\n/g' | grep -i '^openssl.*quic$' | sort -V | tail -n 1)"
    git clone -b "${_openssl30quictls_ver}" 'https://github.com/quictls/openssl.git' 'openssl30quictls'
    sleep 1
    cd openssl30quictls
    rm -fr .git
    sed '/install_docs:/s| install_html_docs||g' -i Configurations/unix-Makefile.tmpl
    LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,\$$ORIGIN' ; export LDFLAGS
    HASHBANGPERL=/usr/bin/perl
    ./Configure \
    --prefix=/usr \
    --libdir=/usr/lib64 \
    --openssldir=/etc/pki/tls \
    enable-ec_nistp_64_gcc_128 \
    zlib enable-tls1_3 threads \
    enable-camellia enable-seed \
    enable-rfc3779 enable-sctp enable-cms \
    enable-md2 enable-rc5 enable-ktls \
    no-mdc2 no-ec2m \
    no-sm2 no-sm3 no-sm4 \
    shared linux-x86_64 '-DDEVRANDOM="\"/dev/urandom\""'
    perl configdata.pm --dump
    make all
    rm -fr /tmp/openssl30quictls
    make DESTDIR=/tmp/openssl30quictls install_sw
    cd /tmp/openssl30quictls
    sed 's|http://|https://|g' -i usr/lib64/pkgconfig/*.pc
    if [[ "$(pwd)" = '/' ]]; then
        echo
        printf '\e[01;31m%s\e[m\n' "Current dir is '/'"
        printf '\e[01;31m%s\e[m\n' "quit"
        echo
        exit 1
    else
        rm -fr lib64
        rm -fr lib
        chown -R root:root ./
    fi
    find usr/ -type f -iname '*.la' -delete
    if [[ -d usr/share/man ]]; then
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
        sleep 2
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 2
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 2
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' /usr/bin/strip '{}'
    fi
    echo
    install -m 0755 -d usr/lib64/nginx/private
    /bin/cp -af usr/lib64/*.so* usr/lib64/nginx/private/
    rm -f /usr/lib64/libssl.*
    rm -f /usr/lib64/libcrypto.*
    rm -fr /usr/include/openssl
    rm -fr /usr/local/openssl-1.1.1
    rm -f /etc/ld.so.conf.d/openssl-1.1.1.conf
    sleep 2
    /bin/cp -afr * /
    sleep 2
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/openssl30quictls
    /sbin/ldconfig
}

############################################################################
#
#
#
############################################################################

rm -fr /usr/lib64/nginx/private
if [ -f /opt/gcc/lib/gcc/x86_64-redhat-linux/11/include-fixed/openssl/bn.h ]; then
    /usr/bin/mv -f /opt/gcc/lib/gcc/x86_64-redhat-linux/11/include-fixed/openssl/bn.h /opt/gcc/lib/gcc/x86_64-redhat-linux/11/include-fixed/openssl/bn.h.orig
fi

_build_zlib
_build_xz
_build_libxml2
_build_libxslt
_build_brotli
_build_libmaxminddb
_build_pcre2
_build_openssl30quictls

_tmp_dir="$(mktemp -d)"
cd "${_tmp_dir}"

_dl_nginx
cd nginx
getent group nginx >/dev/null || groupadd -r nginx
getent passwd nginx >/dev/null || useradd -r -d /var/lib/nginx -g nginx -s /usr/sbin/nologin -c "Nginx web server" nginx

_vmajor=6
_vminor=1
_vpatch=2
_longver=$(printf "%1d%03d%03d" ${_vmajor} ${_vminor} ${_vpatch})
_fullver="$(echo \"${_vmajor}\.${_vminor}\.${_vpatch}\")"
sed "s@#define nginx_version.*@#define nginx_version      ${_longver}@g" -i src/core/nginx.h
sed "s@#define NGINX_VERSION.*@#define NGINX_VERSION      ${_fullver}@g" -i src/core/nginx.h
sed 's@"nginx/"@"gws-v"@g' -i src/core/nginx.h
sed 's@Server: nginx@Server: gws@g' -i src/http/ngx_http_header_filter_module.c
sed 's@<hr><center>nginx</center>@<hr><center>gws</center>@g' -i src/http/ngx_http_special_response.c

_http_module_args="$(./configure --help | grep -i '\--with-http' | awk '{print $1}' | sed 's/^[ ]*//g' | sed 's/[ ]*$//g' | grep -v '=' | sort -u | uniq | grep -iv 'geoip' | paste -sd' ')"
_stream_module_args="$(./configure --help | grep -i '\--with-stream' | awk '{print $1}' | sed 's/^[ ]*//g' | sed 's/[ ]*$//g' | grep -v '=' | sort -u | uniq | grep -iv 'geoip' | paste -sd' ')"

bash /opt/gcc/set-static-libstdcxx

#/bin/cp -f auto/configure configure
LDFLAGS='' ; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,-rpath,/usr/lib64/nginx/private' ; export LDFLAGS
./configure \
--build=x86_64-linux-gnu \
--prefix=/usr/share/nginx \
--sbin-path=/usr/sbin/nginx \
--modules-path=/usr/lib64/nginx/modules \
--conf-path=/etc/nginx/nginx.conf \
--error-log-path=/var/log/nginx/error.log \
--http-log-path=/var/log/nginx/access.log \
--http-client-body-temp-path=/var/lib/nginx/tmp/client_body \
--http-proxy-temp-path=/var/lib/nginx/tmp/proxy \
--http-fastcgi-temp-path=/var/lib/nginx/tmp/fastcgi \
--http-uwsgi-temp-path=/var/lib/nginx/tmp/uwsgi \
--http-scgi-temp-path=/var/lib/nginx/tmp/scgi \
--pid-path=/run/nginx.pid \
--lock-path=/run/lock/subsys/nginx \
--user=nginx \
--group=nginx \
${_http_module_args} \
${_stream_module_args} \
--with-mail \
--with-mail_ssl_module \
--with-file-aio \
--with-poll_module \
--with-select_module \
--with-threads \
--with-pcre \
--with-pcre-jit \
--add-module=../modules/ngx_http_brotli_module \
--add-module=../modules/ngx_http_cache_purge_module \
--add-module=../modules/ngx_http_echo_module \
--add-module=../modules/ngx_http_geoip2_module \
--add-module=../modules/ngx_http_headers_more_filter_module \
--add-module=../modules/ngx_http_memc_module \
--add-module=../modules/ngx_http_redis2_module \
--add-module=../modules/ngx_http_substitutions_filter_module \
--add-module=../modules/ngx_http_naxsi_module/naxsi_src \
--add-module=../modules/ngx_pagespeed \
--add-module=../modules/ngx_rtmp_module \
--with-ld-opt="$LDFLAGS"

make -j2

rm -fr /tmp/nginx
sleep 1
install -m 0755 -d /tmp/nginx/etc/nginx/geoip
sleep 1
make install DESTDIR=/tmp/nginx
install -v -m 0644 ../geoip2/*.mmdb /tmp/nginx/etc/nginx/geoip/

cd /tmp/nginx

install -m 0700 -d var/log/nginx
install -m 0755 -d var/www/html
install -m 0755 -d var/lib/nginx/tmp
install -m 0755 -d usr/lib/systemd/system
install -m 0755 -d usr/lib64/nginx/modules
install -m 0755 -d etc/sysconfig
install -m 0755 -d etc/logrotate.d
install -m 0755 -d etc/nginx/conf.d
install -m 0755 -d etc/systemd/system/nginx.service.d

/bin/cp -afr usr/local/* usr/
sleep 1
rm -fr usr/local

bash /opt/gcc/set-shared-libstdcxx
############################################################################

echo '[Unit]
Description=nginx - high performance web server
Documentation=https://nginx.org/en/docs/
After=network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
# Nginx will fail to start if /run/nginx.pid already exists but has the wrong
# SELinux context. This might happen when running `nginx -t` from the cmdline.
ExecStartPre=/bin/rm -f /run/nginx.pid
ExecStartPre=/usr/sbin/nginx -t
ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx.conf
ExecStartPost=/bin/sleep 0.1
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s TERM $MAINPID
KillSignal=SIGQUIT
TimeoutStopSec=5
KillMode=mixed
PrivateTmp=true

[Install]
WantedBy=multi-user.target' > usr/lib/systemd/system/nginx.service
############################################################################

echo '# Configuration file for the nginx service.

NGINX=/usr/sbin/nginx
CONFFILE=/etc/nginx/nginx.conf' > etc/sysconfig/nginx
############################################################################

printf '\x2F\x76\x61\x72\x2F\x6C\x6F\x67\x2F\x6E\x67\x69\x6E\x78\x2F\x2A\x6C\x6F\x67\x20\x7B\x0A\x20\x20\x20\x20\x63\x72\x65\x61\x74\x65\x20\x30\x36\x34\x34\x20\x72\x6F\x6F\x74\x20\x72\x6F\x6F\x74\x0A\x20\x20\x20\x20\x64\x61\x69\x6C\x79\x0A\x20\x20\x20\x20\x72\x6F\x74\x61\x74\x65\x20\x35\x32\x0A\x20\x20\x20\x20\x6D\x69\x73\x73\x69\x6E\x67\x6F\x6B\x0A\x20\x20\x20\x20\x6E\x6F\x74\x69\x66\x65\x6D\x70\x74\x79\x0A\x20\x20\x20\x20\x63\x6F\x6D\x70\x72\x65\x73\x73\x0A\x20\x20\x20\x20\x73\x68\x61\x72\x65\x64\x73\x63\x72\x69\x70\x74\x73\x0A\x20\x20\x20\x20\x70\x6F\x73\x74\x72\x6F\x74\x61\x74\x65\x0A\x20\x20\x20\x20\x20\x20\x20\x20\x2F\x62\x69\x6E\x2F\x6B\x69\x6C\x6C\x20\x2D\x55\x53\x52\x31\x20\x60\x63\x61\x74\x20\x2F\x72\x75\x6E\x2F\x6E\x67\x69\x6E\x78\x2E\x70\x69\x64\x20\x32\x3E\x2F\x64\x65\x76\x2F\x6E\x75\x6C\x6C\x60\x20\x32\x3E\x2F\x64\x65\x76\x2F\x6E\x75\x6C\x6C\x20\x7C\x7C\x20\x74\x72\x75\x65\x0A\x20\x20\x20\x20\x65\x6E\x64\x73\x63\x72\x69\x70\x74\x0A\x20\x20\x20\x20\x70\x6F\x73\x74\x72\x6F\x74\x61\x74\x65\x0A\x20\x20\x20\x20\x20\x20\x20\x20\x2F\x75\x73\x72\x2F\x73\x62\x69\x6E\x2F\x6E\x67\x69\x6E\x78\x20\x2D\x73\x20\x72\x65\x6C\x6F\x61\x64\x20\x3E\x2F\x64\x65\x76\x2F\x6E\x75\x6C\x6C\x20\x32\x3E\x26\x31\x20\x7C\x7C\x20\x74\x72\x75\x65\x0A\x20\x20\x20\x20\x65\x6E\x64\x73\x63\x72\x69\x70\x74\x0A\x7D\x0A\x0A' | dd seek=$((0x0)) conv=notrunc bs=1 of=etc/logrotate.d/nginx
sleep 1
chmod 0644 etc/logrotate.d/nginx

############################################################################

echo '#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ

#yum makecache && yum install -y glibc gd perl-libs perl

getent group nginx >/dev/null || groupadd -r nginx
getent passwd nginx >/dev/null || useradd -r -d /var/lib/nginx -g nginx -s /usr/sbin/nologin -c "Nginx web server" nginx
[[ -e /etc/nginx/nginx.conf ]] || /bin/cp -v /etc/nginx/nginx.conf.default /etc/nginx/nginx.conf
[[ -e /etc/nginx/mime.types ]] || /bin/cp -v /etc/nginx/mime.types.default /etc/nginx/mime.types
[[ -e /etc/nginx/scgi_params ]] || /bin/cp -v /etc/nginx/scgi_params.default /etc/nginx/scgi_params
[[ -e /etc/nginx/uwsgi_params ]] || /bin/cp -v /etc/nginx/uwsgi_params.default /etc/nginx/uwsgi_params
[[ -e /etc/nginx/fastcgi.conf ]] || /bin/cp -v /etc/nginx/fastcgi.conf.default /etc/nginx/fastcgi.conf
[[ -e /etc/nginx/fastcgi_params ]] || /bin/cp -v /etc/nginx/fastcgi_params.default /etc/nginx/fastcgi_params
[[ -d /var/www/html ]] || install -m 0755 -d /var/www/html
[[ -d /var/lib/nginx ]] || install -m 0755 -d /var/lib/nginx
systemctl daemon-reload >/dev/null 2>&1
chown -R nginx:nginx /var/www/html
chown -R nginx:nginx /var/lib/nginx
systemctl enable nginx.service 2>/dev/null
exit
' > etc/nginx/.postinstall.txt

sed -e 's@#user .* nobody;@user  nginx;@g' \
    -e 's@#pid .*nginx.pid;@pid  /run/nginx.pid;@g' \
    -e '/ root .* html;/s@html;@/var/www/html;@g' \
    -i etc/nginx/nginx.conf.default
sed 's/nginx\/$nginx_version/gws/g' -i etc/nginx/fastcgi.conf.default
sed 's/nginx\/$nginx_version/gws/g' -i etc/nginx/fastcgi_params.default

[[ -e etc/nginx/nginx.conf.default ]] && rm -f etc/nginx/nginx.conf
[[ -e etc/nginx/mime.types.default ]] && rm -f etc/nginx/mime.types
[[ -e etc/nginx/scgi_params.default ]] && rm -f etc/nginx/scgi_params
[[ -e etc/nginx/uwsgi_params.default ]] && rm -f etc/nginx/uwsgi_params
[[ -e etc/nginx/fastcgi.conf.default ]] && rm -f etc/nginx/fastcgi.conf
[[ -e etc/nginx/fastcgi_params.default ]] && rm -f etc/nginx/fastcgi_params

find ./ -type f -name .packlist -exec rm -vf '{}' \;
find ./ -type f -name perllocal.pod -exec rm -vf '{}' \;
find ./ -type f -empty -exec rm -vf '{}' \;
find ./ -type f -iname '*.so' -exec chmod -v 0755 '{}' \;
strip usr/sbin/nginx
find usr/lib64/ -type f -iname '*.so*' -exec file '{}' \; | \
  sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | \
  xargs -I '{}' /usr/bin/strip '{}'
rm -fr run
rm -fr var/run
[ -d usr/man ] && mv -f usr/man usr/share/

/bin/cp -afr /usr/lib64/nginx/private usr/lib64/nginx/
[[ -e /opt/gcc/lib64/libgcc_s.so.1 ]] && /bin/cp -af /opt/gcc/lib64/libgcc_s* usr/lib64/nginx/private/
/bin/cp -af /usr/lib64/perl5/CORE/libperl.so* usr/lib64/nginx/private/
sleep 1
chown -R root:root ./
echo
sleep 2
tar -Jcvf /tmp/gws-"${_vmajor}.${_vminor}.${_vpatch}"-1.el7.x86_64.tar.xz *
echo
sleep 2
cd /tmp
openssl dgst -r -sha256 gws-"${_vmajor}.${_vminor}.${_vpatch}"-1.el7.x86_64.tar.xz | sed 's|\*| |g' > gws-"${_vmajor}.${_vminor}.${_vpatch}"-1.el7.x86_64.tar.xz.sha256
rm -fr "${_tmp_dir}"
rm -fr /tmp/nginx
echo
echo ' build nginx-quic done'
echo
exit

