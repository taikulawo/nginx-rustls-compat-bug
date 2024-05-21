#!/usr/bin/env bash
set -ex
ROOT="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
cd $ROOT
rm -rf output/
mkdir -p output/libs
build_libssl() {
    cd $ROOT
    cd rustls-openssl-compat/rustls-libssl
    cargo b --release
    cp target/release/libssl.so $ROOT/output/libs/libssl.so.3
    ln -sr $ROOT/output/libs/libssl.so.3 $ROOT/output/libs/libssl.so
    cd ../
}

build_openssl3() {
    cd $ROOT/openssl-3.3.0
    [[ -f Makefile ]] && make clean
    ./config no-threads --debug
    make -j$(nproc)
    cp libcrypto.so $ROOT/output/libs/libcrypto.so
    cp libcrypto.so $ROOT/output/libs/libcrypto.so
    ln -sr $ROOT/output/libs/libcrypto.so $ROOT/output/libs/libcrypto.so.3
    cd $ROOT
}
# build nginx
compile_nginx_compat() {
    d="$ROOT/output/nginx_ssl3_compat"
    mkdir -p "$d"
    cd $ROOT/nginx
    [[ -f Makefile ]] && make clean
    # build nginx
    auto/configure --with-ld-opt="-Wl,-rpath,$ROOT/output/libs -L$ROOT/openssl-3.3.0" \
                --with-cc-opt="-O3 -I$ROOT/openssl-3.3.0/include/" --prefix="$d" \
                --with-http_ssl_module \
                --with-stream \
                --with-stream_ssl_module \
                --with-debug
    make -j$(nproc)
    make install
    cd $ROOT
    cp scripts/nginx.conf output/nginx_ssl3_compat/conf/nginx.conf
}

build_libssl
build_openssl3
compile_nginx_compat
./output/nginx_ssl3_compat/sbin/nginx -p "$ROOT/output/nginx_ssl3_compat" -c "conf/nginx.conf"