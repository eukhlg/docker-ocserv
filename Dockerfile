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
	&& apk add --virtual .run-deps "${runDepsArr[@]}" gnutls-utils openssl iptables libnl3 readline libseccomp-dev lz4-dev gettext-envsubst \
	&& apk del .build-deps \
	&& rm -rf /var/cache/apk/*

# Setup config
COPY routes.txt /tmp/

# hadolint ignore=SC2016
RUN sed \
	-e 's/\(^auth = \).*/\1${AUTH}/' \
	-e 's/\.\/sample\.passwd/\/etc\/ocserv\/ocpasswd/' \
	-e 's/\(^tcp-port = \)[0-9]\+/\1${TCP_PORT}/' \
	-e 's/\(^udp-port = \)[0-9]\+/\1${UDP_PORT}/' \
	-e 's/\.\.\/tests/\/etc\/ocserv/' \
	-e 's/\(^isolate-workers = \)true/\1${ISOLATE_WORKERS}/' \
	-e 's/\(^max-clients = \)[0-9]\+/\1${MAX_CLIENTS}/' \
	-e 's/\(^max-same-clients = \)[0-9]\+/\1${MAX_SAME_CLIENTS}/' \
	-e 's/\(^rate-limit-ms = \)[0-9]\+/\1${RATE_LIMIT}/' \
	-e 's/\(^server-stats-reset-time = \)[0-9]\+/\1${SERVER_STATS_RESET}/' \
	-e 's/\(^keepalive = \)[0-9]\+/\1${KEEPALIVE}/' \
	-e 's/\(^dpd = \)[0-9]\+/\1${DPD}/' \
	-e 's/\(^mobile-dpd = \)[0-9]\+/\1${MOBILE_DPD}/' \
	-e 's/\(^switch-to-tcp-timeout = \)[0-9]\+/\1${SWITCH_TO_TCP}/' \
	-e 's/\(^try-mtu-discovery = \)false/\1${MTU_DISCOVERY}/' \
	-e 's/\(^cert-user-oid = \).*/\1${CERT_USER_OID}/' \
	-e 's/#\(compression.*\)/\1/' \
	-e 's/\(^compression = \)false/\1${COMPRESSION}/' \
	-e 's/\(^tls-priorities = \).*/\1${TLS_PRIORITIES}/' \
	-e 's/\(^auth-timeout = \)[0-9]\+/\1${AUTH_TIMEOUT}/' \
	-e 's/\(^min-reauth-time = \)[0-9]\+/\1${MIN_REAUTH_TIME}/' \
	-e 's/\(^max-ban-score = \)[0-9]\+/\1${MAX_BAN_SCORE}/' \
	-e 's/\(^ban-reset-time = \)[0-9]\+/\1${BAN_RESET_TIME}/' \
	-e 's/\(^cookie-timeout = \)[0-9]\+/\1${COOKIE_TIMEOUT}/' \
	-e 's/\(^deny-roaming = \)false/\1${DENY_ROAMING}/' \
	-e 's/\(^rekey-time = \)[0-9]\+/\1${REKEY_TIME}/' \
	-e 's/\(^use-occtl = \)true/\1${USE_OCCTL}/' \
	-e 's/\(^log-level = \)[0-9]\+/\1${LOG_LEVEL}/' \
	-e 's/\(^device = \)vpns/\1${DEV_NAME}/' \
	-e 's/\(^predictable-ips = \)true/\1${PREDICTABLE_IPS}/' \
	-e 's/\(^default-domain = \).*/\1${DEFAULT_DOMAIN}/' \
	-e 's/\(^ipv4-network = \)[0-9]\{1,3\}\([.][0-9]\{1,3\}\)\{3\}/\1${IPV4_NETWORK}/' \
	-e 's/\(^ipv4-netmask = \)[0-9]\{1,3\}\([.][0-9]\{1,3\}\)\{3\}/\1${IPV4_NETMASK}/' \
	-e 's/\(^dns = \)[0-9]\{1,3\}\([.][0-9]\{1,3\}\)\{3\}/\1${IPV4_DNS}/' \
	-e 's/\(^ping-leases = \)false/\1${PING_LEASES}/' \
	-e 's/\(^cisco-client-compat = \)true/\1${CISCO_CLIENT_COMPAT}/' \
	-e 's/\(^dtls-legacy = \)true/\1${DTLS_LEGACY}/' \
	-e 's/\(^cisco-svc-client-compat = \)false/\1${CISCO_SVC_CLIENT_COMPAT}/' \
	-e 's/\(^client-bypass-protocol = \)false/\1${CLIENT_BYPASS_PROTO}/' \
	-e 's/\(^camouflage = \)false/\1${CAMOUFLAGE}/' \
	-e 's/\(^camouflage_secret = \).*/\1${CAMOUFLAGE_SECRET}/' \
	-e 's/\(^camouflage_realm = \).*/\1${CAMOUFLAGE_REALM}/' \
	-e 's/\(.*route.*\)/#\1/' \
	-e '/\[vhost:www.example.com\]/,/cert-user-oid.*/d' \
	-e '/^[[:space:]]*#/d; /^[[:space:]]*$/d' /tmp/ocserv-default.conf > /tmp/ocserv.conf


WORKDIR /etc/ocserv

COPY --chmod=755 docker-entrypoint.sh /entrypoint.sh
COPY --chmod=755 occert.sh /usr/local/bin/occert

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 443
CMD ["ocserv", "-c", "/etc/ocserv/ocserv.conf", "-f"]
