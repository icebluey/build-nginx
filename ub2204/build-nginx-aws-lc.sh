#!/usr/bin/env bash
export PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
TZ='UTC'; export TZ

umask 022

LDFLAGS='-Wl,-z,relro -Wl,--as-needed -Wl,-z,now'
export LDFLAGS
_ORIG_LDFLAGS="${LDFLAGS}"

CC=gcc
export CC
CXX=g++
export CXX
/sbin/ldconfig

_private_dir='usr/lib/x86_64-linux-gnu/nginx/private'

set -e

_strip_files() {
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
        sleep 1
        find usr/share/man/ -type f -iname '*.[1-9]' -exec gzip -f -9 '{}' \;
        sleep 1
        find -L usr/share/man/ -type l | while read file; do ln -svf "$(readlink -s "${file}").gz" "${file}.gz" ; done
        sleep 1
        find -L usr/share/man/ -type l -exec rm -f '{}' \;
    fi
    if [[ -d usr/lib/x86_64-linux-gnu ]]; then
        find usr/lib/x86_64-linux-gnu/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib/x86_64-linux-gnu/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' strip '{}'
        find usr/lib/x86_64-linux-gnu/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' strip '{}'
    fi
    if [[ -d usr/lib64 ]]; then
        find usr/lib64/ -type f \( -iname '*.so' -or -iname '*.so.*' \) | xargs --no-run-if-empty -I '{}' chmod 0755 '{}'
        find usr/lib64/ -iname 'lib*.so*' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' strip '{}'
        find usr/lib64/ -iname '*.so' -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' strip '{}'
    fi
    if [[ -d usr/sbin ]]; then
        find usr/sbin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' strip '{}'
    fi
    if [[ -d usr/bin ]]; then
        find usr/bin/ -type f -exec file '{}' \; | sed -n -e 's/^\(.*\):[  ]*ELF.*, not stripped.*/\1/p' | xargs --no-run-if-empty -I '{}' strip '{}'
    fi
    echo
}

_install_go() {
    set -e
    local _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    # Latest version of go
    #_go_version="$(wget -qO- 'https://golang.org/dl/' | grep -i 'linux-amd64\.tar\.' | sed 's/"/\n/g' | grep -i 'linux-amd64\.tar\.' | cut -d/ -f3 | grep -i '\.gz$' | sed 's/go//g; s/.linux-amd64.tar.gz//g' | grep -ivE 'alpha|beta|rc' | sort -V | uniq | tail -n 1)"

    # go1.25.X
    _go_version="$(wget -qO- 'https://golang.org/dl/' | grep -i 'linux-amd64\.tar\.' | sed 's/"/\n/g' | grep -i 'linux-amd64\.tar\.' | cut -d/ -f3 | grep -i '\.gz$' | sed 's/go//g; s/.linux-amd64.tar.gz//g' | grep -ivE 'alpha|beta|rc' | sort -V | uniq | grep '^1\.25\.' | tail -n 1)"

    wget -q -c -t 0 -T 9 "https://dl.google.com/go/go${_go_version}.linux-amd64.tar.gz"
    rm -fr /usr/local/go
    sleep 1
    install -m 0755 -d /usr/local/go
    tar -xof "go${_go_version}.linux-amd64.tar.gz" --strip-components=1 -C /usr/local/go/
    sleep 1
    cd /tmp
    rm -fr "${_tmp_dir}"
}

_build_zlib() {
    /sbin/ldconfig
    set -e
    local _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _zlib_ver="$(wget -qO- 'https://www.zlib.net/' | grep 'zlib-[1-9].*\.tar\.' | sed -e 's|"|\n|g' | grep '^zlib-[1-9]' | sed -e 's|\.tar.*||g' -e 's|zlib-||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://www.zlib.net/zlib-${_zlib_ver}.tar.gz"
    tar -xof zlib-*.tar.*
    sleep 1
    rm -f zlib-*.tar*
    cd zlib-*
    ./configure --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --64
    make -j$(nproc --all) all
    rm -fr /tmp/zlib
    make DESTDIR=/tmp/zlib install
    cd /tmp/zlib
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    /bin/rm -f /usr/lib/x86_64-linux-gnu/libz.so*
    /bin/rm -f /usr/lib/x86_64-linux-gnu/libz.a
    sleep 1
    /bin/cp -afr * /
    sleep 1
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/zlib
    /sbin/ldconfig
}

_build_libxml2() {
    /sbin/ldconfig
    set -e
    local _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    #_libxml2_ver="$(wget -qO- 'https://gitlab.gnome.org/GNOME/libxml2/-/tags' | grep '\.tar\.' | sed -e 's|"|\n|g' -e 's|/|\n|g' | grep -i '^libxml2-.*\.tar\..*' | grep -ivE 'alpha|beta|rc[1-9]' | sed -e 's|.*libxml2-v||g' -e 's|\.tar.*||g' | grep '^[1-9]' | sort -V | uniq | tail -n 1)"
    _libxml2_ver="$(wget -qO- 'https://gitlab.gnome.org/GNOME/libxml2/-/tags' | grep '\.tar\.' | sed -e 's|"|\n|g' -e 's|/|\n|g' | grep -i '^libxml2-.*\.tar\..*' | grep -ivE 'alpha|beta|rc[1-9]' | sed -e 's|.*libxml2-v||g' -e 's|\.tar.*||g' | grep '^[1-9]' | grep '2\.13\.' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://download.gnome.org/sources/libxml2/${_libxml2_ver%.*}/libxml2-${_libxml2_ver}.tar.xz"
    tar -xof libxml2-*.tar.*
    sleep 1
    rm -f libxml2-*.tar*
    cd libxml2-*
    find doc -type f -executable -print -exec chmod 0644 {} ';'
    LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,--disable-new-dtags -Wl,-rpath,\$$ORIGIN'; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --with-legacy --with-ftp --with-xptr-locs --without-python \
    --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
    sed 's|^hardcode_libdir_flag_spec=.*|hardcode_libdir_flag_spec=""|g' -i libtool
    make -j$(nproc --all) all
    rm -fr /tmp/libxml2
    make install DESTDIR=/tmp/libxml2
    cd /tmp/libxml2
    # multiarch crazyness on timestamp differences or Makefile/binaries for examples
    touch -m --reference=usr/include/libxml2/libxml/parser.h usr/bin/xml2-config
    rm -fr usr/share/doc
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    #rm -f /usr/lib/x86_64-linux-gnu/libxml2.*
    sleep 1
    /bin/cp -afr * /
    sleep 1
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/libxml2
    /sbin/ldconfig
}

_build_libxslt() {
    /sbin/ldconfig
    set -e
    local _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _libxslt_ver="$(wget -qO- 'https://gitlab.gnome.org/GNOME/libxslt/-/tags' | grep '\.tar\.' | sed -e 's|"|\n|g' -e 's|/|\n|g' | grep -i '^libxslt-.*\.tar\..*' | grep -ivE 'alpha|beta|rc[1-9]' | sed -e 's|.*libxslt-v||g' -e 's|\.tar.*||g' | grep '^[1-9]' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 https://download.gnome.org/sources/libxslt/${_libxslt_ver%.*}/libxslt-${_libxslt_ver}.tar.xz
    tar -xof libxslt-${_libxslt_ver}.tar.*
    sleep 1
    rm -f libxslt-*.tar*
    cd libxslt-*
    LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,--disable-new-dtags -Wl,-rpath,\$$ORIGIN'; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --without-python --without-crypto \
    --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
    sed 's|^hardcode_libdir_flag_spec=.*|hardcode_libdir_flag_spec=""|g' -i libtool
    make -j$(nproc --all) all
    rm -fr /tmp/libxslt
    make install DESTDIR=/tmp/libxslt
    cd /tmp/libxslt
    # multiarch crazyness on timestamp differences or Makefile/binaries for examples
    touch -m --reference=usr/include/libxslt/xslt.h usr/bin/xslt-config
    rm -fr usr/share/doc
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    rm -f /usr/lib/x86_64-linux-gnu/libxslt.*
    rm -f /usr/lib/x86_64-linux-gnu/libexslt.*
    sleep 1
    /bin/cp -afr * /
    sleep 1
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/libxslt
    /sbin/ldconfig
}

_build_libmaxminddb() {
    /sbin/ldconfig
    set -e
    local _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    git clone --recursive 'https://github.com/maxmind/libmaxminddb.git' libmaxminddb
    cd libmaxminddb
    rm -fr .git
    rm -f ltmain.sh
    ./bootstrap
    rm -fr autom4te.cache
    LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,--disable-new-dtags -Wl,-rpath,\$$ORIGIN'; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --disable-static \
    --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
    make -j$(nproc --all) all
    rm -fr /tmp/libmaxminddb
    make install DESTDIR=/tmp/libmaxminddb
    cd /tmp/libmaxminddb
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 1
    /bin/cp -afr * /
    sleep 1
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/libmaxminddb
    /sbin/ldconfig
}

_build_brotli() {
    /sbin/ldconfig
    set -e
    local _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    git clone --recursive 'https://github.com/google/brotli.git' brotli
    cd brotli
    rm -fr .git
    if [[ -f bootstrap ]]; then
        ./bootstrap
        rm -fr autom4te.cache
        LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,--disable-new-dtags -Wl,-rpath,\$$ORIGIN'; export LDFLAGS
        ./configure \
        --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
        --enable-shared --disable-static \
        --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
        make -j$(nproc --all) all
        rm -fr /tmp/brotli
        make install DESTDIR=/tmp/brotli
    else
        LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,--disable-new-dtags -Wl,-rpath,\$ORIGIN'; export LDFLAGS
        cmake \
        -S "." \
        -B "build" \
        -DCMAKE_BUILD_TYPE='Release' \
        -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
        -DCMAKE_INSTALL_PREFIX:PATH=/usr \
        -DINCLUDE_INSTALL_DIR:PATH=/usr/include \
        -DLIB_INSTALL_DIR:PATH=/usr/lib/x86_64-linux-gnu \
        -DSYSCONF_INSTALL_DIR:PATH=/etc \
        -DSHARE_INSTALL_PREFIX:PATH=/usr/share \
        -DLIB_SUFFIX=64 \
        -DBUILD_SHARED_LIBS:BOOL=ON \
        -DCMAKE_INSTALL_SO_NO_EXE:INTERNAL=0
        cmake --build "build" --parallel $(nproc --all) --verbose
        rm -fr /tmp/brotli
        DESTDIR="/tmp/brotli" cmake --install "build"
    fi
    cd /tmp/brotli
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 1
    /bin/cp -afr * /
    sleep 1
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/brotli
    /sbin/ldconfig
}

_build_aws-lc() {
    set -e
    local _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _aws_lc_tag="$(wget -qO- 'https://github.com/aws/aws-lc/tags' | grep -i 'href="/.*/releases/tag/' | sed 's|"|\n|g' | grep -i '/releases/tag/' | sed 's|.*/tag/||g' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://github.com/aws/aws-lc/archive/refs/tags/${_aws_lc_tag}.tar.gz"
    tar -xof *.tar*
    sleep 1
    rm -f *.tar*
    cd aws*
    # Go programming language
    export GOROOT='/usr/local/go'
    export GOPATH="$GOROOT/home"
    export GOTMPDIR='/tmp'
    export GOBIN="$GOROOT/bin"
    export PATH="$GOROOT/bin:$PATH"
    alias go="$GOROOT/bin/go"
    alias gofmt="$GOROOT/bin/gofmt"
    rm -fr ~/.cache/go-build
    echo
    go version
    echo
    LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,--disable-new-dtags -Wl,-rpath,\$ORIGIN'; export LDFLAGS
    cmake \
    -GNinja \
    -S "." \
    -B "aws-lc-build" \
    -DCMAKE_BUILD_TYPE='Release' \
    -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON \
    -DCMAKE_INSTALL_PREFIX:PATH=/usr \
    -DINCLUDE_INSTALL_DIR:PATH=/usr/include \
    -DLIB_INSTALL_DIR:PATH=/usr/lib/x86_64-linux-gnu \
    -DSYSCONF_INSTALL_DIR:PATH=/etc \
    -DSHARE_INSTALL_PREFIX:PATH=/usr/share \
    -DLIB_SUFFIX=64 \
    -DBUILD_SHARED_LIBS:BOOL=ON \
    -DCMAKE_INSTALL_SO_NO_EXE:INTERNAL=0
    cmake --build "aws-lc-build" --parallel $(nproc --all) --verbose
    rm -fr /tmp/aws-lc
    DESTDIR="/tmp/aws-lc" cmake --install "aws-lc-build"
    cd /tmp/aws-lc
    sed 's|http://|https://|g' -i usr/lib/x86_64-linux-gnu/pkgconfig/*.pc
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    rm -vf usr/bin/openssl
    rm -vf usr/bin/c_rehash
    rm -fr /usr/include/openssl
    rm -fr /usr/include/x86_64-linux-gnu/openssl
    rm -vf /usr/lib/x86_64-linux-gnu/libssl.so
    rm -vf /usr/lib/x86_64-linux-gnu/libcrypto.so
    sleep 1
    /bin/cp -afr * /
    sleep 1
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/aws-lc
    /sbin/ldconfig
}

_build_pcre2() {
    /sbin/ldconfig
    set -e
    local _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    _pcre2_ver="$(wget -qO- 'https://github.com/PCRE2Project/pcre2/releases' | grep -i 'pcre2-[1-9]' | sed 's|"|\n|g' | grep -i '^/PCRE2Project/pcre2/tree' | sed 's|.*/pcre2-||g' | sed 's|\.tar.*||g' | grep -ivE 'alpha|beta|rc' | sort -V | uniq | tail -n 1)"
    wget -c -t 9 -T 9 "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${_pcre2_ver}/pcre2-${_pcre2_ver}.tar.bz2"
    tar -xof pcre2-${_pcre2_ver}.tar.*
    sleep 1
    rm -f pcre2-*.tar*
    cd pcre2-*
    LDFLAGS=''; LDFLAGS="${_ORIG_LDFLAGS}"' -Wl,--disable-new-dtags -Wl,-rpath,\$$ORIGIN'; export LDFLAGS
    ./configure \
    --build=x86_64-linux-gnu --host=x86_64-linux-gnu \
    --enable-shared --enable-static \
    --enable-pcre2-8 --enable-pcre2-16 --enable-pcre2-32 \
    --enable-jit --enable-unicode \
    --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --includedir=/usr/include --sysconfdir=/etc
    sed 's|^hardcode_libdir_flag_spec=.*|hardcode_libdir_flag_spec=""|g' -i libtool
    make -j$(nproc --all) all
    rm -fr /tmp/pcre2
    make install DESTDIR=/tmp/pcre2
    cd /tmp/pcre2
    rm -fr usr/share/doc/pcre2/html
    _strip_files
    install -m 0755 -d "${_private_dir}"
    cp -af usr/lib/x86_64-linux-gnu/*.so* "${_private_dir}"/
    sleep 1
    /bin/cp -afr * /
    sleep 1
    cd /tmp
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/pcre2
    /sbin/ldconfig
}

_build_nginx() {
    getent group nginx >/dev/null || groupadd -r nginx
    getent passwd nginx >/dev/null || useradd -r -d /var/lib/nginx -g nginx -s /usr/sbin/nologin -c "Nginx web server" nginx
    /sbin/ldconfig
    set -e
    local _tmp_dir="$(mktemp -d)"
    cd "${_tmp_dir}"
    # 1.26
    #_nginx_ver="$(wget -qO- 'https://github.com/nginx/nginx/tags' | grep -i 'tags/release-.*.tar.gz' | sed -e 's|"|\n|g' -e 's|/|\n|g' | grep -i '^release-' | sed -e 's|release-||g' -e 's|\.tar.*||g' | sort -V | uniq | grep '1\.26' | tail -n 1)"
    # 1.28
    #_nginx_ver="$(wget -qO- 'https://github.com/nginx/nginx/tags' | grep -i 'tags/release-.*.tar.gz' | sed -e 's|"|\n|g' -e 's|/|\n|g' | grep -i '^release-' | sed -e 's|release-||g' -e 's|\.tar.*||g' | sort -V | uniq | grep '1\.28' | tail -n 1)"

    # 1.29
    _nginx_ver="$(wget -qO- 'https://github.com/nginx/nginx/tags' | grep -i 'tags/release-.*.tar.gz' | sed -e 's|"|\n|g' -e 's|/|\n|g' | grep -i '^release-' | sed -e 's|release-||g' -e 's|\.tar.*||g' | sort -V | uniq | grep '1\.29' | tail -n 1)"

    wget -c -t 9 -T 9 "https://nginx.org/download/nginx-${_nginx_ver}.tar.gz"
    tar -xof nginx*.tar*
    sleep 1
    rm -f release*.tar*
    rm -f nginx*.tar*

    _dl_modules_orig() {
        git clone "https://github.com/nbs-system/naxsi.git" ngx_http_naxsi_module
        git clone "https://github.com/nginx-modules/ngx_cache_purge.git" ngx_http_cache_purge_module
        git clone "https://github.com/arut/nginx-rtmp-module.git" ngx_rtmp_module
        git clone "https://github.com/leev/ngx_http_geoip2_module.git" ngx_http_geoip2_module
        git clone "https://github.com/yaoweibin/ngx_http_substitutions_filter_module.git" ngx_http_substitutions_filter_module
        git clone --recursive "https://github.com/google/ngx_brotli.git" ngx_http_brotli_module
        git clone "https://github.com/openresty/redis2-nginx-module.git" ngx_http_redis2_module
        git clone "https://github.com/openresty/memc-nginx-module.git" ngx_http_memc_module
        git clone "https://github.com/openresty/echo-nginx-module.git" ngx_http_echo_module
        git clone "https://github.com/openresty/headers-more-nginx-module.git" ngx_http_headers_more_filter_module
    
        #git clone "https://github.com/apache/incubator-pagespeed-ngx.git" ngx_pagespeed
        #wget -c "https://dl.google.com/dl/page-speed/psol/1.13.35.2-x64.tar.gz" -O psol.tar.gz
        #wget -c "https://raw.githubusercontent.com/icebluey/build-nginx/refs/heads/master/psol/1.13.35.2-x64.tar.gz" -O psol.tar.gz
        #wget -c "https://github.com/icebluey/build-nginx/raw/refs/heads/master/psol/psol-jammy.tar.gz"
        #tar -xof psol*.tar* -C ngx_pagespeed/
        #sleep 1
        #rm -f psol*.tar.gz
    }

    _dl_modules_me() {
        git clone "https://github.com/icebluey/naxsi.git" ngx_http_naxsi_module
        git clone "https://github.com/icebluey/ngx_cache_purge.git" ngx_http_cache_purge_module
        git clone "https://github.com/icebluey/nginx-rtmp-module.git" ngx_rtmp_module
        git clone "https://github.com/icebluey/ngx_http_geoip2_module.git" ngx_http_geoip2_module
        git clone "https://github.com/icebluey/ngx_http_substitutions_filter_module.git" ngx_http_substitutions_filter_module
        git clone --recursive "https://github.com/google/ngx_brotli.git" ngx_http_brotli_module
        git clone "https://github.com/icebluey/redis2-nginx-module.git" ngx_http_redis2_module
        git clone "https://github.com/icebluey/memc-nginx-module.git" ngx_http_memc_module
        git clone "https://github.com/icebluey/echo-nginx-module.git" ngx_http_echo_module
        git clone "https://github.com/icebluey/headers-more-nginx-module.git" ngx_http_headers_more_filter_module
    
        #git clone "https://github.com/icebluey/incubator-pagespeed-ngx.git" ngx_pagespeed
        #wget -c "https://dl.google.com/dl/page-speed/psol/1.13.35.2-x64.tar.gz" -O psol.tar.gz
        #wget -c "https://raw.githubusercontent.com/icebluey/build-nginx/refs/heads/master/psol/1.13.35.2-x64.tar.gz" -O psol.tar.gz
        #wget -c "https://github.com/icebluey/build-nginx/raw/refs/heads/master/psol/psol-jammy.tar.gz"
        #tar -xof psol*.tar* -C ngx_pagespeed/
        #sleep 1
        #rm -f psol*.tar.gz
    }
 
    mkdir modules
    cd modules
    _dl_modules_orig
    #_dl_modules_me
    cd ..

    cd nginx-*
    # apply aws-lc patch
    rm -fr /tmp/aws-lc-nginx.patch
    wget -c -t 9 -T 9 'https://raw.githubusercontent.com/icebluey/build-nginx/refs/heads/master/nginx-patches/aws-lc-nginx-1.29.1.patch' -O /tmp/aws-lc-nginx.patch
    patch -N -p 1 -i /tmp/aws-lc-nginx.patch
    sleep 1
    rm -f /tmp/aws-lc-nginx.patch
    _vmajor=2
    _vminor=9
    _vpatch=11
    _longver=$(printf "%1d%03d%03d" ${_vmajor} ${_vminor} ${_vpatch})
    _fullver="$(echo \"${_vmajor}\.${_vminor}\.${_vpatch}\")"
    sed "s@#define nginx_version.*@#define nginx_version      ${_longver}@g" -i src/core/nginx.h
    sed "s@#define NGINX_VERSION.*@#define NGINX_VERSION      ${_fullver}@g" -i src/core/nginx.h
    sed 's@"nginx/"@"gws-v"@g' -i src/core/nginx.h
    sed 's@Server: nginx@Server: gws@g' -i src/http/ngx_http_header_filter_module.c
    sed 's@<hr><center>nginx</center>@<hr><center>gws</center>@g' -i src/http/ngx_http_special_response.c
    _http_module_args="$(./configure --help | grep -i '\--with-http' | awk '{print $1}' | sed 's/^[ ]*//g' | sed 's/[ ]*$//g' | grep -v '=' | sort -u | uniq | grep -iv 'geoip' | paste -sd' ')"
    _stream_module_args="$(./configure --help | grep -i '\--with-stream' | awk '{print $1}' | sed 's/^[ ]*//g' | sed 's/[ ]*$//g' | grep -v '=' | sort -u | uniq | grep -iv 'geoip' | paste -sd' ')"
    LDFLAGS=''; export LDFLAGS
    #./auto/configure \
    ./configure \
    --build=x86_64-linux-gnu \
    --prefix=/usr/share/nginx \
    --sbin-path=/usr/sbin/nginx \
    --modules-path=/usr/lib/x86_64-linux-gnu/nginx/modules \
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
    --with-compat \
    --add-module=../modules/ngx_http_brotli_module \
    --add-module=../modules/ngx_http_cache_purge_module \
    --add-module=../modules/ngx_http_echo_module \
    --add-module=../modules/ngx_http_geoip2_module \
    --add-module=../modules/ngx_http_headers_more_filter_module \
    --add-module=../modules/ngx_http_memc_module \
    --add-module=../modules/ngx_http_redis2_module \
    --add-module=../modules/ngx_http_substitutions_filter_module \
    --add-module=../modules/ngx_http_naxsi_module/naxsi_src \
    --add-module=../modules/ngx_rtmp_module \
    --with-cc-opt='-g -O2 -flto=auto -ffat-lto-objects -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC' \
    --with-ld-opt='-Wl,-Bsymbolic-functions -flto=auto -ffat-lto-objects -Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie'
    make -j$(nproc --all)
    rm -fr /tmp/nginx
    make install DESTDIR=/tmp/nginx
    cd /tmp/nginx
    #install -m 0755 -d var/www/html
    #install -m 0755 -d var/lib/nginx/tmp
    #install -m 0700 -d var/log/nginx
    install -m 0755 -d usr/lib/x86_64-linux-gnu/nginx/modules
    install -m 0755 -d etc/sysconfig
    #install -m 0755 -d usr/lib/systemd/system
    #install -m 0755 -d etc/systemd/system/nginx.service.d
    #install -m 0755 -d etc/logrotate.d
    install -m 0755 -d etc/nginx/conf.d
    install -m 0755 -d etc/nginx/geoip
    [ -d usr/local ] && cp -fr usr/local/* usr/
    sleep 1
    rm -fr usr/local
    sed 's/nginx\/$nginx_version/gws/g' -i etc/nginx/fastcgi.conf
    sed 's/nginx\/$nginx_version/gws/g' -i etc/nginx/fastcgi_params
    sed 's/nginx\/$nginx_version/gws/g' -i etc/nginx/fastcgi.conf.default
    sed 's/nginx\/$nginx_version/gws/g' -i etc/nginx/fastcgi_params.default
    sed 's@#user .* nobody;@user  nginx;@g' -i etc/nginx/nginx.conf
    sed 's@#user .* nobody;@user  nginx;@g' -i etc/nginx/nginx.conf.default
    sed 's@#pid .*nginx.pid;@pid  /run/nginx.pid;@g' -i etc/nginx/nginx.conf
    sed 's@#pid .*nginx.pid;@pid  /run/nginx.pid;@g' -i etc/nginx/nginx.conf.default
    sed '/ root .* html;/s@html;@/var/www/html;@g' -i etc/nginx/nginx.conf
    sed '/ root .* html;/s@html;@/var/www/html;@g' -i etc/nginx/nginx.conf.default
    rm -fr etc/nginx/nginx.conf*
    _strip_files
    install -m 0755 -d usr/lib/x86_64-linux-gnu/nginx
    cp -afr /"${_private_dir}" usr/lib/x86_64-linux-gnu/nginx/
    patchelf --force-rpath --add-rpath '$ORIGIN/../lib/x86_64-linux-gnu/nginx/private' usr/sbin/nginx
    echo
    find /tmp/nginx -type f -name .packlist -exec rm -vf '{}' \;
    find /tmp/nginx -type f -name perllocal.pod -exec rm -vf '{}' \;
    find /tmp/nginx -type f -empty -exec rm -vf '{}' \;
    find /tmp/nginx -type f -iname '*.so' -exec chmod -v 0755 '{}' \;
    rm -fr run
    #rm -fr var/run
    rm -fr var
    [ -d usr/man ] && mv -f usr/man usr/share/

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
WantedBy=multi-user.target' > etc/nginx/nginx.service

echo '
systemctl daemon-reload >/dev/null 2>&1 || : 
systemctl stop nginx.service >/dev/null 2>&1 || : 
systemctl disable nginx.service >/dev/null 2>&1 || : 
userdel -f -r nginx >/dev/null 2>&1 || : 
groupdel nginx >/dev/null 2>&1 || : 
rm -f /usr/sbin/nginx
rm -f /lib/systemd/system/nginx.service
rm -fr /usr/share/nginx
rm -f /usr/share/man/man3/nginx.3*
rm -fr /etc/systemd/system/nginx.service.d
rm -f /etc/logrotate.d/nginx
rm -f /etc/sysconfig/nginx
rm -f /etc/nginx/scgi_params.default
rm -f /etc/nginx/fastcgi.conf
rm -f /etc/nginx/fastcgi_params
rm -f /etc/nginx/koi-win
rm -f /etc/nginx/uwsgi_params
rm -f /etc/nginx/nginx.conf.default*
rm -f /etc/nginx/mime.types.default
rm -f /etc/nginx/uwsgi_params.default
rm -f /etc/nginx/win-utf
rm -f /etc/nginx/koi-utf
rm -f /etc/nginx/fastcgi_params.default
rm -f /etc/nginx/mime.types
rm -f /etc/nginx/fastcgi.conf.default
rm -f /etc/nginx/scgi_params
rm -fr /etc/nginx/geoip
rm -fr /etc/nginx/conf.d
rm -fr /var/lib/nginx
rm -fr /var/log/nginx
rm -fr /usr/lib/x86_64-linux-gnu/nginx
rm -fr /usr/lib/x86_64-linux-gnu/perl/5.30.0/auto/nginx
rm -f /usr/lib/x86_64-linux-gnu/perl/5.30.0/nginx.pm
rm -fr /usr/lib/x86_64-linux-gnu/perl/5.34.0/auto/nginx
rm -f /usr/lib/x86_64-linux-gnu/perl/5.34.0/nginx.pm
rm -f /etc/nginx/nginx.service
systemctl daemon-reload >/dev/null 2>&1 || : 
' > etc/nginx/.del.txt

echo '
cd "$(dirname "$0")"
systemctl daemon-reload >/dev/null 2>&1 || : 
getent group nginx > /dev/null || groupadd -r nginx
getent passwd nginx > /dev/null || useradd -r -d /var/lib/nginx -g nginx -s /usr/sbin/nologin -c "Nginx web server" nginx
rm -f /lib/systemd/system/nginx.service
install -v -c -m 0644 nginx.service /lib/systemd/system/
[ -d /etc/logrotate.d ] || install -m 0755 -d /etc/logrotate.d
echo '\''/var/log/nginx/*log {
    create 0644 root root
    daily
    rotate 52
    missingok
    notifempty
    compress
    sharedscripts
    postrotate
        /usr/bin/killall -HUP rsyslogd 2> /dev/null || true
        /usr/bin/killall -HUP syslogd 2> /dev/null || true
        /usr/sbin/nginx -s reload 2> /dev/null || true
    endscript
}'\'' >/etc/logrotate.d/nginx
chmod 0644 /etc/logrotate.d/nginx
[ -d /etc/systemd/system/nginx.service.d ] || install -m 0755 -d /etc/systemd/system/nginx.service.d
[ -d /var/lib/nginx/tmp ] || install -m 0755 -d /var/lib/nginx/tmp
[ -d /var/www/html ] || install -m 0755 -d /var/www/html
[ -d /var/log/nginx ] || install -m 0755 -d /var/log/nginx
chown -R nginx:nginx /var/www/html
chown -R nginx:nginx /var/lib/nginx
systemctl daemon-reload >/dev/null 2>&1 || : 

' > etc/nginx/.install.txt

chmod 0644 etc/nginx/nginx.service
chmod 0644 etc/nginx/.del.txt
chmod 0644 etc/nginx/.install.txt

echo '<!DOCTYPE html>
<html>
<head>
<title>Welcome to gws!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to gws!</h1>
</body>
</html>' > usr/share/nginx/html/index.html
chmod 0644 usr/share/nginx/html/index.html

echo '# Configuration file for the nginx service.
NGINX=/usr/sbin/nginx
CONFFILE=/etc/nginx/nginx.conf' > etc/sysconfig/nginx
chmod 0644 etc/sysconfig/nginx

    rm -f etc/nginx/nginx.conf*
    wget -c -t 9 -T 9 'https://raw.githubusercontent.com/icebluey/build-nginx/refs/heads/master/conf/nginx.conf' -O etc/nginx/nginx.conf
    wget -c -t 9 -T 9 'https://raw.githubusercontent.com/icebluey/build-nginx/refs/heads/master/conf/nginx.conf2' -O etc/nginx/nginx.conf.default2
    mv -f etc/nginx/nginx.conf etc/nginx/nginx.conf.default
    chmod 0644 etc/nginx/nginx.conf*
    rm -f etc/nginx/conf.d/default.conf
    wget -c -t 9 -T 9 'https://raw.githubusercontent.com/icebluey/build-nginx/refs/heads/master/conf/default.conf' -O etc/nginx/conf.d/default.conf
    chmod 0644 etc/nginx/conf.d/default.conf
    wget -c -t 9 -T 9 'https://raw.githubusercontent.com/icebluey/build-nginx/refs/heads/master/conf/h2.conf' -O etc/nginx/conf.d/h2.conf.example
    wget -c -t 9 -T 9 'https://raw.githubusercontent.com/icebluey/build-nginx/refs/heads/master/conf/h3.conf' -O etc/nginx/conf.d/h3.conf.example
    wget -c -t 9 -T 9 'https://raw.githubusercontent.com/icebluey/build-nginx/refs/heads/master/conf/opt.conf' -O etc/nginx/conf.d/opt.conf.example
    chmod 0644 etc/nginx/conf.d/*conf*
    sleep 1
    tar -Jcvf /tmp/nginx-"${_nginx_ver}"_"awslc${_aws_lc_tag/v/}"-1_ub2204_amd64.tar.xz *
    echo
    sleep 1
    cd /tmp
    openssl dgst -r -sha256 nginx-"${_nginx_ver}"_"awslc${_aws_lc_tag/v/}"-1_ub2204_amd64.tar.xz | sed 's|\*| |g' > nginx-"${_nginx_ver}"_"awslc${_aws_lc_tag/v/}"-1_ub2204_amd64.tar.xz.sha256
    rm -fr "${_tmp_dir}"
    rm -fr /tmp/nginx
    /sbin/ldconfig
}

############################################################################

rm -fr /usr/lib/x86_64-linux-gnu/nginx

_build_zlib
_build_libxml2
_build_libxslt
_build_libmaxminddb
_build_brotli

_install_go
_build_aws-lc

_build_pcre2
_build_nginx

rm -fr /tmp/_output
mkdir /tmp/_output
mv -f /tmp/nginx-*.tar* /tmp/_output/

echo
echo ' build nginx aws-lc ub2204 done'
echo
exit

