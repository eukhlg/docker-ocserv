FROM alpine:3.20.3

ENV OC_VERSION=1.3.0

RUN apk add --no-cache bash

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]

RUN buildDeps=( \
		curl \
		g++ \
		gnutls-dev \
		gpgme \
		libev-dev \
		libnl3-dev \
		libseccomp-dev \
		linux-headers \
		linux-pam-dev \
		lz4-dev \
		make \
		readline-dev \
		tar \
		xz \
	) \
	&& apk add --update --virtual .build-deps "${buildDeps[@]}" \
	&& curl -SL --connect-timeout 8 --max-time 120 --retry 128 --retry-delay 5 "ftp://ftp.infradead.org/pub/ocserv/ocserv-$OC_VERSION.tar.xz" -o ocserv.tar.xz \
	&& mkdir -p /usr/src/ocserv \
	&& tar -xf ocserv.tar.xz -C /usr/src/ocserv --strip-components=1 \
	&& rm ocserv.tar.xz* \
	&& cd /usr/src/ocserv \
	&& ./configure \
	&& make \
	&& make install \
	&& mkdir -p /etc/ocserv \
	&& cp /usr/src/ocserv/doc/sample.config /tmp/ocserv-default.conf \
	&& cd / \
	&& rm -fr /usr/src/ocserv \
	&& runDeps="$( \
		scanelf --needed --nobanner /usr/local/sbin/ocserv \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| xargs -r apk info --installed \
			| sort -u \
		)" \
	&& readarray runDepsArr <<< "$runDeps" \
	&& apk add --virtual .run-deps "${runDepsArr[@]}" gnutls-utils iptables libnl3 readline libseccomp-dev lz4-dev gettext-envsubst \
	&& apk del .build-deps \
	&& rm -rf /var/cache/apk/*

# Setup config
COPY routes.txt /tmp/

# hadolint ignore=SC2016
RUN sed \
 	-e 's/^auth.*/auth = ${AUTH}/' \
	-e 's/\.\/sample\.passwd/\/etc\/ocserv\/ocpasswd/' \
	-e 's/\(max-same-clients = \)2/\110/' \
	-e 's/\.\.\/tests/\/etc\/ocserv/' \
	-e 's/^cert-user-oid.*/cert-user-oid = ${CERT_USER_OID}/' \
	-e 's/#\(compression.*\)/\1/' \
	-e '/^ipv4-network = /{s/192.168.1.0/${IPV4_NETWORK}/}' \
	-e '/^ipv4-netmask = /{s/255.255.255.0/${IPV4_NETMASK}/}' \
	-e '/^dns = /{s/192.168.1.2/${IPV4_DNS}/}' \
	-e 's/^route/#route/' \
	-e 's/^no-route/#no-route/' \
	-e '/\[vhost:www.example.com\]/,$d' \
	-e '/^cookie-timeout = /{s/300/3600/}' \
	-e 's/^isolate-workers/#isolate-workers/' /tmp/ocserv-default.conf > /tmp/ocserv.conf \
	&& cat /tmp/routes.txt >> /tmp/ocserv.conf

WORKDIR /etc/ocserv

COPY --chmod=755 docker-entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 443
CMD ["ocserv", "-c", "/etc/ocserv/ocserv.conf", "-f"]
