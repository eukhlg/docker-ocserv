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
Get the docker image by running the following commands:

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


|   Variable       |      Default     |                          Description                               |
|:----------------:|:----------------:|:------------------------------------------------------------------:|
|  **CA_CN**       |      VPN CA      | Common name used to generate the CA (Certificate Authority)        |
|  **CA_ORG**      |     Big Corp     | Organization name used to generate the CA                          |
| **CA_DAYS**      |       9999       | Expiration days used to generate the CA                            |
|  **SRV_CN**      | www.example.com  | Common name used to generate the server certification              |
| **SRV_ORG**      |    My Company    | Organization name used to generate the server certification        |
| **SRV_DAYS**     |       9999       | Expiration days used to generate the server certification          |
| **AUTH**         |       plain      | Client authentication method can be 'plain' or 'cert'              |
| **TEST_USER**    |       test       | Name of test user. If not set test user is not created             |
| **CLIENT_DAYS**  |       9999       | Expiration days used to generate the client certification          |
| **IPV4_NETWORK** |   192.168.99.0   | Pool of tunnel IP addresses that leases will be given from         |
| **IPV4_NETMASK** |   255.255.255.0  | Network mask for pool of tunnel IP addresses                       |
| **IPV4_DNS**     |      8.8.8.8     | Advertised DNS server for pool of tunnel IP addresses              |

### Running examples

Start an instance out of the box with username `test` and password `test`

```bash
docker run \
  --name ocserv \
  --detach \
  --sysctl net.ipv4.ip_forward=1 \
  --cap-add NET_ADMIN \
  --security-opt no-new-privileges \
  --publish 443:443 \
  --publish 443:443/udp \
  --env TEST_USER=test \
  eukhlg/ocserv
```

Start an instance with server name `my.test.com`, `My Test` and `365` days

```bash
docker run \
  --name ocserv \
  --detach \
  --sysctl net.ipv4.ip_forward=1 \
  --cap-add NET_ADMIN \
  --security-opt no-new-privileges \
  --publish 443:443 \
  --publish 443:443/udp \
  --env TEST_USER=test \
  --env SRV_CN=my.test.com \
  --env SRV_ORG="My Test" \
  --env SRV_DAYS=365 \
  eukhlg/ocserv
```

Start an instance with CA name `My CA`, `My Corp` and `3650` days

```bash
docker run \
  --name ocserv \
  --detach \
  --sysctl net.ipv4.ip_forward=1 \
  --cap-add NET_ADMIN \
  --security-opt no-new-privileges \
  --publish 443:443 \
  --publish 443:443/udp \
  --env TEST_USER=test \
  --env CA_CN="My CA" \
  --env CA_ORG="My Corp" \
  --env CA_DAYS=3650 \
  eukhlg/ocserv
```

Start an instance as above but without test user

```bash
docker run \
  --name ocserv \
  --detach \
  --sysctl net.ipv4.ip_forward=1 \
  --cap-add NET_ADMIN \
  --security-opt no-new-privileges \
  --publish 443:443 \
  --publish 443:443/udp \
  --env CA_CN="My CA" \
  --env CA_ORG="My Corp" \
  --env CA_DAYS=3650 \
  eukhlg/ocserv
```

### User operations (plain authentication)

All the users opertaions happened while the container is running. If you used a different container name other than `ocserv`, then you have to change the container name accordingly.

#### List all users

```bash
docker exec -it ocserv cut -d: -f1 /etc/ocserv/ocpasswd
```

#### Add user

If say, you want to create a user named `test`, type the following command

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
