#!/usr/bin/env bash

ROOT="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
cd $ROOT

build_libssl() {
    cd $ROOT
    mkdir -p output/libs
    cd rustls-openssl-compat
    cargo b --release
    cp target/release/libssl.so $ROOT/output/libs/libssl.so.3
    ln -sr $ROOT/output/libs/libssl.so.3 $ROOT/output/libs/libssl.so
    cd ../
}

build_openssl3() {
    cd openssl-3.3.0
    [[ -f Makefile ]] && make clean
    ./config no-threads
    make -j$(nproc)
    cp libcrypto.so $ROOT/output/libs/libcrypto.so
    ln -sr $ROOT/output/libs/libcrypto.so $ROOT/output/libs/libcrypto.so.3
    cd $ROOT
}
# build nginx
compile_nginx_compat() {
    build_openssl3
    d="$ROOT/output/nginx_ssl3_compat"
    mkdir -p "$d"
    cd $ROOT/nginx
    [[ -f Makefile ]] && make clean
    # patch -p1 -i $ROOT/scripts/nginx_libssl.so.compat.patch
    # build nginx
    auto/configure --with-ld-opt="-Wl,-rpath,$ROOT/output/libs -L$ROOT/openssl-3.3.0" \
                --with-cc-opt="-O3 -I$ROOT/openssl-3.3.0/include/" --prefix="$d"
    make -j$(nproc)
    make install
    cd $ROOT
    cp scripts/nginx.conf output/nginx+ssl3_compat/conf/nginx.conf
}

build_libssl
build_openssl3
compile_nginx_compat
$ROOT/output/nginx_ssl3_compat/sbin/nginx -p $ROOT/output/nginx_ssl3_compat -c conf/nginx.conf