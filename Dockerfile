# Build Stage

ARG BASE_VERSION=3.21.0

FROM alpine:${BASE_VERSION} AS builder

ARG OC_VERSION=1.3.0

RUN apk add --no-cache \
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
	&& curl -SL --connect-timeout 8 --max-time 120 --retry 128 --retry-delay 5 \
		"ftp://ftp.infradead.org/pub/ocserv/ocserv-${OC_VERSION}.tar.xz" -o ocserv.tar.xz \
	&& mkdir -p /usr/src/ocserv \
	&& tar -xf ocserv.tar.xz -C /usr/src/ocserv --strip-components=1 \
	&& rm ocserv.tar.xz* \
	&& cd /usr/src/ocserv \
	&& ./configure \
	&& make \
	&& make install

# Runtime Stage
FROM alpine:${BASE_VERSION}

# Set environment variables
ENV WORKDIR="/etc/ocserv"
ENV CONFIG_FILE="${WORKDIR}/ocserv.conf"
ENV DEFAULT_CONFIG_FILE="/tmp/ocserv-default.conf"
ENV SERVER_CERT_DIR="${WORKDIR}/certs"
ENV CLIENT_CERT_DIR="${SERVER_CERT_DIR}/client"

# Copy compiled binary from builder stage
COPY --from=builder /usr/local/sbin/ /usr/local/sbin/
COPY --from=builder /usr/local/bin/ /usr/local/bin/
COPY --from=builder /usr/src/ocserv/doc/sample.config ${DEFAULT_CONFIG_FILE}

# Install run dependencies
# Getting required libraries from /usr/local/sbin/ocserv with scanelf, 
# then extracting packages name from it with apk info and pass this to apk add
RUN apk update \
    && runDeps="$(apk list | grep "$(scanelf --needed --nobanner /usr/local/sbin/ocserv \
        | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
        | xargs -r -n1 -I{} sh -c 'apk info "{}" | head -n1 \
        | sed "s/ description:.*//"')" \
        | awk -F'[{}]' '{print $2}' | sort -u)" \
    && apk add --no-cache ${runDeps} \
	curl \
	gettext-envsubst \
	iptables \
	libcap \
	libnl3 \
	libseccomp-dev \
	lz4-dev \
    openssl \
	readline

# Create ocserv user
RUN addgroup -S ocserv \
    && adduser -S ocserv -G ocserv 
    #&& setcap cap_net_admin,cap_net_raw+ep /usr/local/sbin/ocserv \
	#&& setcap cap_net_admin,cap_net_raw+ep /usr/local/sbin/ocserv-worker

# Create ocserv folders
RUN mkdir -p /etc/ocserv /var/run/ocserv \
	&& chown -R ocserv:ocserv /var/run/ocserv

COPY --chmod=755 docker-entrypoint.sh /entrypoint.sh
COPY --chmod=755 occert.sh /usr/local/bin/occert

#USER ocserv
WORKDIR ${WORKDIR}

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 443
CMD ["/bin/sh", "-c", "ocserv -c \"${CONFIG_FILE}\" -f -d 2"]