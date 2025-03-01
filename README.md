# docker-ocserv

docker-ocserv is an OpenConnect VPN Server boxed in a Docker image originally built by [Tommy Lau](mailto:tommy@gen-new.com) and [Amin Vakil](mailto:info@aminvakil.com).

This project is fork with some additions. 

## What is OpenConnect Server?

[OpenConnect server (ocserv)](http://www.infradead.org/ocserv/) is an SSL VPN server. It implements the OpenConnect SSL VPN protocol, and has also (currently experimental) compatibility with clients using the [AnyConnect SSL VPN](http://www.cisco.com/c/en/us/support/security/anyconnect-vpn-client/tsd-products-support-series-home.html) protocol.

## How to use this image

Install docker:

```bash
curl -L https://get.docker.com | sh && sudo usermod -aG docker $USER
```
Pull the docker image by running the following commands:

```bash
docker pull eukhlg/ocserv
```

Start an ocserv instance:

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

This will start an instance without any users created.

### Environment Variables


|   Variable            |      Default     |                          Description                                      |
|:---------------------:|:----------------:|:-------------------------------------------------------------------------:|
| **ORG_NAME**          |   BigCorp Inc    | Organization name, which will be used in configuration                    |
| **HOST_NAME**         |  bigcorp.com     | Server domain/host name                                                   |
| **AUTH**              |       plain      | Client authentication method can be 'plain' or 'cert'                     |
| **CA_CN**             | $ORG_NAME Root CA | Common name used to generate the CA (Certificate Authority)              |
| **CA_ORG**            |     $ORG_NAME    | Organization name used to generate the CA                                 |
| **CA_DAYS**           |       1825       | Expiration days used to generate the CA                                   |
| **SRV_CN**            | $ORG_NAME Server CA | Common name used to generate the server certification                  |
| **SRV_ORG**           |    $ORG_NAME     | Organization name used to generate the server certification               |
| **SRV_DAYS**          |       1825       | Expiration days used to generate the server certification                 |
| **USER_NAME**         |                  | Name of default user. If not set user is not created                      |
| **USER_PASSWORD**     |                  | Default user password                                                     | 
| **CLIENT_DAYS**       |       365        | Expiration days used to generate the client certification                 |
| **IPV4_NETWORK**      |   192.168.99.0   | Pool of tunnel IP addresses that leases will be given from                |
| **IPV4_NETMASK**      |   255.255.255.0  | Network mask for pool of tunnel IP addresses                              |
| **IPV4_DNS**          |      8.8.8.8     | Advertised DNS server for pool of tunnel IP addresses                     |
| **ROUTE**             |   default        | Routes to be forwarded to the client                                      |
| **NO_ROUTE**          |   192.168.0.0/16; 10.0.0.0/8; 172.16.0.0/12 | Subsets of the routes that will not be routed by the server. Comma/Semicolon/Space separated.|
| **ISOLATE_WORKERS**   |       true       | Whether to enable seccomp/Linux namespaces worker isolation               |
| **MAX_CLIENTS**       |       16         | Limit the number of clients. Unset or set to zero if unknown              |
| **MAX_SAME_CLIENTS**  |       2          | Limit the number of identical clients                                     |
| **RATE_LIMIT**        |      100         | Rate limit the number of incoming connections to one every X milliseconds |
| **SERVER_STATS_RESET**|     604800       | Stats reset time. The period of time statistics kept                      |
| **KEEPALIVE**         |     32400        | Keepalive in seconds                                                      |
| **DPD**               |      90          | Dead peer detection in seconds                                            |
| **MOBILE_DPD**        |     1800         | Dead peer detection for mobile clients                                    |
| **SWITCH_TO_TCP**     |      25          | For DTLS, while no UDP traffic is received for 25 seconds switch to TCP   |
| **MTU_DISCOVERY**     |     false        | MTU discovery (DPD must be enabled)                                       |
| **COMPRESSION**       |     false        | Enables compression negotiation (LZS, LZ4)                                |
| **TLS_PRIORITIES**    |     <string>     | GnuTLS priority string; note that SSL 3.0 is disabled by default          |
| **AUTH_TIMEOUT**      |      240         | The time (in seconds) that a client is allowed to stay unauthenticated    |
| **MIN_REAUTH_TIME**   |      300         | The time that a client is not allowed to reconnect after failed auth      |
| **MAX_BAN_SCORE**     |      80          | Banning score. By default a wrong password attempt is 10 points           |
| **BAN_RESET_TIME**    |      1200        | The time (in seconds) that all score kept for a client is reset           |
| **COOKIE_TIMEOUT**    |      300         | Cookie timeout (in seconds), get invalid if not used within this value    |
| **DENY_ROAMING**      |      false       | If true a cookie is restricted to a single IP address                     |
| **REKEY_TIME**        |      172800      | Server asks the client to refresh keys once time (in seconds) is elapsed  |
| **USE_OCCTL**         |      true        | Whether to enable support for the occtl tool                              |
| **LOG_LEVEL**         |       2          | Log level; 0=default, 1=basic, 2=info, 3=debug, 4=http, 8=sensitive, 9=TLS|  
| **DEV_NAME**          |      vpns        | The name to use for the tun device                                        |
| **PREDICTABLE_IPS**   |      true        | If true, IP stays the same for the same user when possible                |
| **DEFAULT_DOMAIN**    |   example.com    | The default domain to be advertised; Multiple domains to separated w space|
| **PING_LEASES**       |      false       | Prior to leasing any IP ping it to verify that it is not in use           |
| **MTU**                 |      1420      | Use this option to set a link MTU value to the incoming connections  |
| **CISCO_CLIENT_COMPAT**|     true        | Must by set to true to support legacy CISCO clients & openconnect < 7.08  |
| **DTLS_LEGACY**       |      true        | This option allows one to disable the legacy DTLS negotiation             |
| **CISCO_SVC_CLIENT_COMPAT**| false       | This option will enable the settings needed for Cisco SVC IPPhone clients |
| **CLIENT_BYPASS_PROTO**|     false       | Enables the X-CSTP-Client-Bypass-Protocol                                 |
| **CAMOUFLAGE**        |      false       | Enables the camouflage feature of ocserv that makes it look as web server |
| **CAMOUFLAGE_SECRET** |   mysecretkey    | The URL prefix to pass through the camouflage                             |
| **CAMOUFLAGE_REALM**  | Restricted Content| Defines the realm (browser prompt) for HTTP authentication               |

### Updating image to the latest version

```bash
docker stop ocserv && docker rm ocserv && docker image prune --all -f && docker pull eukhlg/ocserv
```
Then you have to tun container with your options (see Running examples)

#### If using docker compose

```bash
docker compose pull && docker compose up -d
```

### Running examples

Start an instance out of the box with username `test` and random password.

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
Password can be found in docker logs:

```bash
docker logs ocserv 2>&1 | grep -i password
```

Start an instance with organization name `My Test`, serever name `my.test.com`, CA and Server certificate valid for `365` days

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

Start an instance as above but without default user

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

### User operations (plain authentication)

All the users opertaions happened while the container is running. If you used a different container name other than `ocserv`, then you have to change the container name accordingly.

#### List all users

```bash
docker exec -it ocserv cut -d: -f1 /etc/ocserv/ocpasswd
```

#### Add user

To create a user named `test`, type the following command

```bash
docker exec -ti ocserv ocpasswd -c /etc/ocserv/ocpasswd test
Enter password:
Re-enter password:
```

When prompt for password, type the password twice, then you will have the user with the password you want.

#### Delete user

Delete user is similar to add user, just add another argument `-d` to the command line

```bash
docker exec -ti ocserv ocpasswd -c /etc/ocserv/ocpasswd -d test
```

#### Change password

Change password is exactly the same command as add user, please refer to the command mentioned above.

### User operations (certificate authentication)

#### Add user

To create a certificate for user `test`, type the following command

```bash
docker exec -it ocserv occert test
```
By default user certificate is valid for `365` days and P12 certificate password is empty.

To create a certificate for user `test`, with password `testpass` and certificate valid for 30 days type the following command

```bash
docker exec -it ocserv occert test testpass 30
```
