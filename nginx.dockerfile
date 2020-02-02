#!/usr/bin/env -S docker build --compress -t pvtmert/nginx -f

ARG VERSION=1.17.8
ARG PREFIX=/nginx

#FROM centos:7 as build
#RUN yum install -y \
#	gcc \
#	gcc-c++ \
#	make \
#	perl \
#	libatomic \
#	pcre-devel \
#	pcre2-devel \
#	openssl-devel \
#	libxml2-devel \
#	libxslt-devel \
#	gd-devel \
#	zlib-devel \
#	geoip-devel \
#	gperftools-devel

FROM debian:stable as build
RUN apt update
RUN apt install -y \
	build-essential \
	libgoogle-perftools-dev \
	libatomic-ops-dev \
	libpcre-ocaml-dev \
	libpcre++-dev \
	libpcre3-dev \
	libpcre2-dev \
	libgeoip-dev \
	libxslt1-dev \
	libxml2-dev \
	libssl-dev \
	zlib1g-dev \
	libatomic1 \
	libgd-dev \
	curl perl

ARG VERSION
WORKDIR /data
RUN curl -#L "https://nginx.org/download/nginx-${VERSION}.tar.gz" \
	| tar --strip=1 -xz

ARG PREFIX
RUN ( ./configure \
		--prefix="${PREFIX}" \
		--with-cc-opt=" "    \
		--with-ld-opt=" "    \
		--with-select_module                    \
		--with-poll_module                      \
		--with-threads                          \
		--with-file-aio                         \
		--with-http_ssl_module                  \
		--with-http_v2_module                   \
		--with-http_realip_module               \
		--with-http_addition_module             \
		--with-http_xslt_module                 \
		--with-http_xslt_module=dynamic         \
		--with-http_image_filter_module         \
		--with-http_image_filter_module=dynamic \
		--with-http_geoip_module                \
		--with-http_geoip_module=dynamic        \
		--with-http_sub_module                  \
		--with-http_dav_module                  \
		--with-http_flv_module                  \
		--with-http_mp4_module                  \
		--with-http_gunzip_module               \
		--with-http_gzip_static_module          \
		--with-http_auth_request_module         \
		--with-http_random_index_module         \
		--with-http_secure_link_module          \
		--with-http_degradation_module          \
		--with-http_slice_module                \
		--with-http_stub_status_module          \
		--with-mail                             \
		--with-mail=dynamic                     \
		--with-mail_ssl_module                  \
		--with-stream                           \
		--with-stream=dynamic                   \
		--with-stream_ssl_module                \
		--with-stream_realip_module             \
		--with-stream_geoip_module              \
		--with-stream_geoip_module=dynamic      \
		--with-stream_ssl_preread_module        \
		--with-google_perftools_module          \
		--with-cpp_test_module                  \
		--with-compat                           \
		--with-pcre                             \
		--with-pcre-jit                         \
		--with-libatomic                        \
		--with-debug                            \
	)

#&& mkdir -p ./build \
#&& cd ./build       \
#&& cp -r ../auto ./ \
#--with-openssl                          \
#--with-http_perl_module                 \
#--with-http_perl_module=dynamic         \

RUN make \
	-C . \
	-j$(nproc) \
	build install

FROM debian:stable
RUN apt update
RUN apt install -y \
	libgoogle-perftools4 \
	libssl1.1 \
	openssl

ARG PREFIX
WORKDIR "${PREFIX}"
COPY --from=build "${PREFIX}" ./
RUN ln -sf /dev/stderr "${PREFIX}/logs/error.log"
RUN ln -sf /dev/stdout "${PREFIX}/logs/access.log"
RUN ./sbin/nginx -t
CMD ./sbin/nginx -g 'daemon off;'

ARG CERT_FILE=/ssl
ARG CERT_HOST=localhost
ARG CERT_DAYS=3650
ARG CERT_SIZE=4096
RUN openssl req \
	-new        \
	-x509       \
	-sha256     \
	-nodes      \
	-newkey "rsa:${CERT_SIZE}" \
	-keyout "${CERT_FILE}.key" \
	-out    "${CERT_FILE}.crt" \
	-days   "${CERT_DAYS}"     \
	-subj   "/CN=${CERT_HOST}"
