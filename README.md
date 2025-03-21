# docker-ocserv

**docker-ocserv** is a Docker image for running an OpenConnect VPN server (ocserv). This project is a fork of the original work by [Tommy Lau](mailto:tommy@gen-new.com) and [Amin Vakil](mailto:info@aminvakil.com), with additional enhancements.

## What is OpenConnect Server?

[OpenConnect Server (ocserv)](http://www.infradead.org/ocserv/) is an SSL VPN server. It implements the OpenConnect SSL VPN protocol and offers experimental compatibility with clients using the [AnyConnect SSL VPN](http://www.cisco.com/c/en/us/support/security/anyconnect-vpn-client/tsd-products-support-series-home.html) protocol.

## How to Use This Image

### Prerequisites

1. **Install Docker**:
   ```bash
   curl -L https://get.docker.com | sh && sudo usermod -aG docker $USER
   ```

2. **Pull the Docker Image**:
   ```bash
   docker pull eukhlg/ocserv
   ```

3. **Start an ocserv Instance**:
   ```bash
   docker run \
     --name ocserv \
     --detach \
     --sysctl net.ipv4.ip_forward=1 \
     --cap-add NET_ADMIN \
     --security-opt no-new-privileges \
     --publish 443:443 \
     --publish 443:443/udp \
     eukhlg/ocserv
   ```
   This command starts an instance without any pre-configured users.

---

## Environment Variables

The following environment variables can be used to customize the ocserv instance:

| Variable                  | Default               | Description                                                                 |
|---------------------------|-----------------------|-----------------------------------------------------------------------------|
| **ORG_NAME**              | `BigCorp Inc`         | Organization name used in configuration.                                    |
| **HOST_NAME**             | `vpn.bigcorp.com`     | Server domain name.                                                    |
| **AUTH**                  | `plain`               | Client authentication method: `plain` or `cert`.                            |
| **CA_CN**                 | `BigCorp Inc Root CA`| Common name for the Certificate Authority (CA). By default constructed as `ORG_NAME` Root CA. |
| **CA_ORG**                | `BigCorp Inc`         | Organization name for the CA. By default equals `ORG_NAME`.            |
| **CA_DAYS**               | `1825`                | Expiration days for the CA.                                                 |
| **SRV_CN**                | `BigCorp Inc Server CA` | Common name for the server certificate. By default generated as `ORG_NAME` Server CA. |
| **SRV_ORG**               | `BigCorp Inc`         | Organization name for the server certificate. By default equals `ORG_NAME`. |
| **SRV_DAYS**              | `1825`                | Expiration days for the server certificate.                                 |
| **USER_NAME**             | `-`                   | Default username. If not set, no user is created.                           |
| **USER_PASSWORD**         | `-`                   | Default user password. If not set, random password is generated. For `cert` authentication stands for `PKCS#12` (.p12) import password.       |
| **CLIENT_DAYS**           | `365`                 | Expiration days for client certificates.                                    |
| **IPV4_NETWORK**          | `192.168.99.0`        | Pool of tunnel IP addresses.                                                |
| **IPV4_NETMASK**          | `255.255.255.0`       | Network mask for the tunnel IP pool.                                        |
| **IPV4_DNS**              | `8.8.8.8`             | DNS server advertised to clients.                                           |
| **ROUTE**                 | `default`             | Routes to be forwarded to the client.                                       |
| **NO_ROUTE**              | `192.168.0.0/16; 10.0.0.0/8; 172.16.0.0/12` | Subnets excluded from routing. Use commas, semicolons, or spaces to separate. |
| **ISOLATE_WORKERS**       | `true`                | Enable seccomp/Linux namespaces for worker isolation.                       |
| **MAX_CLIENTS**           | `16`                  | Maximum number of clients. Set to `0` for no limit.                         |
| **MAX_SAME_CLIENTS**      | `2`                   | Maximum number of identical clients.                                        |
| **RATE_LIMIT**            | `100`                 | Rate limit for incoming connections (milliseconds).                         |
| **SERVER_STATS_RESET**    | `604800`              | Stats reset period (seconds).                                               |
| **KEEPALIVE**             | `32400`               | Keepalive timeout (seconds).                                                |
| **DPD**                   | `90`                  | Dead peer detection timeout (seconds).                                      |
| **MOBILE_DPD**            | `1800`                | Dead peer detection timeout for mobile clients (seconds).                   |
| **SWITCH_TO_TCP**         | `25`                  | Switch to TCP if no UDP traffic is received for this duration (seconds).    |
| **MTU_DISCOVERY**         | `false`               | Enable MTU discovery (requires DPD).                                        |
| **COMPRESSION**           | `false`               | Enable compression negotiation (LZS, LZ4).                                 |
| **TLS_PRIORITIES**        | `<string>`            | GnuTLS priority string (SSL 3.0 is disabled by default).                    |
| **AUTH_TIMEOUT**          | `240`                 | Time (seconds) a client can remain unauthenticated.                         |
| **MIN_REAUTH_TIME**       | `300`                 | Time (seconds) before a client can reconnect after failed authentication.   |
| **MAX_BAN_SCORE**         | `80`                  | Banning score (wrong password attempt = 10 points).                        |
| **BAN_RESET_TIME**        | `1200`                | Time (seconds) before a client's ban score is reset.                        |
| **COOKIE_TIMEOUT**        | `300`                 | Cookie timeout (seconds).                                                   |
| **DENY_ROAMING**          | `false`               | Restrict cookies to a single IP address.                                    |
| **REKEY_TIME**            | `172800`              | Time (seconds) before the server requests a key refresh.                    |
| **USE_OCCTL**             | `true`                | Enable support for the `occtl` tool.                                        |
| **LOG_LEVEL**             | `2`                   | Log level: `0`=default, `1`=basic, `2`=info, `3`=debug, `4`=http, `8`=sensitive, `9`=TLS. |
| **DEV_NAME**              | `vpns`                | Name of the tun device.                                                     |
| **PREDICTABLE_IPS**       | `true`                | Assign the same IP to a user when possible.                                 |
| **DEFAULT_DOMAIN**        | `vpn.bigcorp.com`     | Default domain advertised to clients. Multiple domains can be space-separated. By default equals `HOST_NAME`. |
| **PING_LEASES**           | `false`               | Ping IPs before leasing to ensure they are unused.                          |
| **MTU**                   | `1420`                | MTU value for incoming connections.                                         |
| **CISCO_CLIENT_COMPAT**   | `true`                | Enable compatibility with legacy Cisco clients and OpenConnect < 7.08.      |
| **DTLS_LEGACY**           | `true`                | Enable legacy DTLS negotiation.                                             |
| **CISCO_SVC_CLIENT_COMPAT** | `false`             | Enable settings for Cisco SVC IPPhone clients.                              |
| **CLIENT_BYPASS_PROTO**   | `false`               | Enable `X-CSTP-Client-Bypass-Protocol`.                                     |
| **CAMOUFLAGE**            | `false`               | Make ocserv appear as a web server.                                         |
| **CAMOUFLAGE_SECRET**     | `mysecretkey`         | URL prefix for camouflage.                                                  |
| **CAMOUFLAGE_REALM**      | `Restricted Content`  | Realm for HTTP authentication (browser prompt).                             |

---

## Updating the Image

To update to the latest version of the image:

```bash
docker stop ocserv && docker rm ocserv && docker image prune --all -f && docker pull eukhlg/ocserv
```

Then restart the container with your desired options (see examples below).

### Using Docker Compose

If using Docker Compose, run:

```bash
docker compose pull && docker compose up -d
```

---

## Running Examples

### Start a Default Instance

Start an instance with a default user `test` and a random password:

```bash
docker run \
  --name ocserv \
  --detach \
  --sysctl net.ipv4.ip_forward=1 \
  --cap-add NET_ADMIN \
  --security-opt no-new-privileges \
  --publish 443:443 \
  --publish 443:443/udp \
  --env USER_NAME=test \
  eukhlg/ocserv
```

To retrieve the generated password for user 'test':

```bash
docker exec it ocserv cat /etc/.test
```

### Start an Instance with Custom Settings

Start an instance with organization name `My Test`, server name `my.test.com`, and CA/server certificates valid for `365` days:

```bash
docker run \
  --name ocserv \
  --detach \
  --sysctl net.ipv4.ip_forward=1 \
  --cap-add NET_ADMIN \
  --security-opt no-new-privileges \
  --publish 443:443 \
  --publish 443:443/udp \
  --env USER_NAME=test \
  --env ORG_NAME="My Test" \
  --env HOST_NAME="my.test.com" \
  --env CA_DAYS=365 \
  --env SRV_DAYS=365 \
  eukhlg/ocserv
```

### Start an Instance Without a Default User

Start an instance without creating a default user:

```bash
docker run \
  --name ocserv \
  --detach \
  --sysctl net.ipv4.ip_forward=1 \
  --cap-add NET_ADMIN \
  --security-opt no-new-privileges \
  --publish 443:443 \
  --publish 443:443/udp \
  --env ORG_NAME="My Test" \
  --env HOST_NAME="my.test.com" \
  --env CA_DAYS=365 \
  --env SRV_DAYS=365 \
  eukhlg/ocserv
```

---

## User Operations (Plain Authentication)

All user operations are performed while the container is running. If you used a container name other than `ocserv`, replace `ocserv` with your container name.

### List All Users

```bash
docker exec -it ocserv cut -d: -f1 /etc/ocserv/ocpasswd
```

### Add a User

To create a user named `test`:

```bash
docker exec -it ocserv ocpasswd -c /etc/ocserv/ocpasswd test
```

You will be prompted to enter and confirm the password.

### Delete a User

To delete a user:

```bash
docker exec -it ocserv ocpasswd -c /etc/ocserv/ocpasswd -d test
```

### Change a User's Password

To change a user's password, use the same command as adding a user:

```bash
docker exec -it ocserv ocpasswd -c /etc/ocserv/ocpasswd test
```

---

## User Operations (Certificate Authentication)

If `cert` authentication metod is set and **USER_PASSWORD** variable is not set, then random PKCS#12 (.p12) import password is set.

To retrieve the generated `PKCS#12` (.p12) import password for user 'test':

```bash
docker exec it ocserv cat /etc/.test
```


### Add a User

To create a certificate for user `test` with a password (`testpass`):

```bash
docker exec -it ocserv occert test testpass
```

By default, the certificate is valid for `365` days.

To create the same user with certificate validity of `30` days:

```bash
docker exec -it ocserv occert test testpass 30
```
