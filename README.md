# docker-ocserv

docker-ocserv is an OpenConnect VPN Server boxed in a Docker image originally built by [Tommy Lau](mailto:tommy@gen-new.com) and [Amin Vakil](mailto:info@aminvakil.com).

This project is fork with some additions. 

## What is OpenConnect Server?

[OpenConnect server (ocserv)](http://www.infradead.org/ocserv/) is an SSL VPN server. It implements the OpenConnect SSL VPN protocol, and has also (currently experimental) compatibility with clients using the [AnyConnect SSL VPN](http://www.cisco.com/c/en/us/support/security/anyconnect-vpn-client/tsd-products-support-series-home.html) protocol.

## How to use this image

Install docker:

```bash
curl -L https://get.docker.com | sh
```
Get the docker image by running the following commands:

```bash
docker pull eukhlg/ocserv
```

Start an ocserv instance:

```bash
docker run --name ocserv --sysctl net.ipv4.ip_forward=1 --cap-add NET_ADMIN --security-opt no-new-privileges -p 443:443 -p 443:443/udp -d eukhlg/ocserv
```

This will start an instance with the a test user named `test` and password is also `test`.

### Environment Variables


|   Variable       |      Default     |                          Description                          |
|:----------------:|:----------------:|:-------------------------------------------------------------:|
|  **CA_CN**       |      VPN CA      | Common name used to generate the CA (Certificate Authority)   |
|  **CA_ORG**      |     Big Corp     | Organization name used to generate the CA                     |
| **CA_DAYS**      |       9999       | Expiration days used to generate the CA                       |
|  **SRV_CN**      | www.example.com  | Common name used to generate the server certification         |
| **SRV_ORG**      |    My Company    | Organization name used to generate the server certification   |
| **SRV_DAYS**     |       9999       | Expiration days used to generate the server certification     |
| **IPV4_NETWORK** |   192.168.99.0   | Pool of tunnel IP addresses that leases will be given from    |
| **IPV4_NETMASK** |   255.255.255.0  | Network mask for pool of tunnel IP addresses                  |
| **IPV4_DNS**     |      8.8.8.8     | Advertised DNS server for pool of tunnel IP addresses         |

### Running examples

Start an instance out of the box with username `test` and password `test`

```bash
docker run --name ocserv --sysctl net.ipv4.ip_forward=1 --cap-add NET_ADMIN --security-opt no-new-privileges -p 443:443 -p 443:443/udp -d eukhlg/ocserv
```

Start an instance with server name `my.test.com`, `My Test` and `365` days

```bash
docker run --name ocserv --sysctl net.ipv4.ip_forward=1 --cap-add NET_ADMIN --security-opt no-new-privileges -p 443:443 -p 443:443/udp -e SRV_CN=my.test.com -e SRV_ORG="My Test" -e SRV_DAYS=365 -d eukhlg/ocserv
```

Start an instance with CA name `My CA`, `My Corp` and `3650` days

```bash
docker run --name ocserv --sysctl net.ipv4.ip_forward=1 --cap-add NET_ADMIN --security-opt no-new-privileges -p 443:443 -p 443:443/udp -e CA_CN="My CA" -e CA_ORG="My Corp" -e CA_DAYS=3650 -d eukhlg/ocserv
```

A totally customized instance with both CA and server certification

```bash
docker run --name ocserv --sysctl net.ipv4.ip_forward=1 --cap-add NET_ADMIN --security-opt no-new-privileges -p 443:443 -p 443:443/udp -e CA_CN="My CA" -e CA_ORG="My Corp" -e CA_DAYS=3650 -e SRV_CN=my.test.com -e SRV_ORG="My Test" -e SRV_DAYS=365 -d eukhlg/ocserv
```

Start an instance as above but without test user

```bash
docker run --name ocserv --sysctl net.ipv4.ip_forward=1 --cap-add NET_ADMIN --security-opt no-new-privileges -p 443:443 -p 443:443/udp -e CA_CN="My CA" -e CA_ORG="My Corp" -e CA_DAYS=3650 -e SRV_CN=my.test.com -e SRV_ORG="My Test" -e SRV_DAYS=365 -e NO_TEST_USER=1 -v /some/path/to/ocpasswd:/etc/ocserv/ocpasswd -d eukhlg/ocserv
```

**WARNING:** The ocserv requires the ocpasswd file to start, if `NO_TEST_USER=1` is provided, there will be no ocpasswd created, which will stop the container immediately after start it. You must specific a ocpasswd file pointed to `/etc/ocserv/ocpasswd` by using the volume argument `-v` by docker as demonstrated above.

### User operations

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

The above command will delete the default user `test`, if you start the instance without using environment variable `NO_TEST_USER`.

#### Change password

Change password is exactly the same command as add user, please refer to the command mentioned above.
