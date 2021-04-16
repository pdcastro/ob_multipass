
# Ubuntu VM setup for openBalena using multipass

This _unofficial_ guide provides fairly reproducible/automatable steps to create
a couple of Ubuntu virtual machines for openBalena on your local development
workstation (instead of a cloud provider like AWS) -- a VM for the openBalena
server, and another for the "local machine" where the balena CLI is installed.

It closely follows openBalena's official [Getting Started
Guide](https://www.balena.io/open/docs/getting-started/), but automates several
steps with scripts, uses local VMs instead of AWS, and is somewhat opinionated
regarding some installation options and the use of Canonical's `multipass` tool
(https://multipass.run).

These VMs should get you a working openBalena installation to compare with or
revert to, while debugging issues or learning more about openBalena. Use them
as a reference and starting point for customization to your needs.

## Install multipass

Install multipass as per instructions on https://multipass.run/

## Networking

We need the VMs to be able to reach each other over the network. A relatively
easy way of achieving this is by having the VMs connect to the host OS network
(bridge). For this purpose, on macOS and Windows, set VirtualBox as the
multipass "driver" with the command:

```sh
sudo multipass set local.driver=virtualbox
```

Use `multipass networks` to find the name of a network interface that provides
Internet access to the host OS. In the example below, it is the WiFi interface
named "en0":

```sh
$ multipass networks
Name     Type         Description
en0      wifi         Wi-Fi (Wireless)
en1      thunderbolt  Thunderbolt 1
...
```

For more details about multipass networking options, see:
https://multipass.run/docs/additional-networks

A proper openBalena setup will make use a dedicated internet domain name and
CNAME records. For testing / experiments, this guide sets up hostname entries in
the `/etc/hosts` file of the `localmachine` VM, allowing any dummy domain name
to be used, like `'open.balena'`. However, this is not enough for balenaOS
devices to be able to reach the openBalena server. Use real CNAME records or a
custom local DNS and DHCP server (like
[dnsmasq](https://thekelleys.org.uk/dnsmasq/doc.html)) if balenaOS devices are
part of the test / experiment (not part of this guide).

## Launch the VMs

The following commands launch two virtual machines named `'openbalena'` and
`'localmachine'` respectively, with 4GB RAM, 50GB disk (maximum limit - disk
space will be allocated as needed), 4 processor cores, bridging to the `en0`
network interface (see previous section), and based on the Ubuntu 20.04 image.

```sh
multipass launch -n openbalena -m 4G -d 50G -c 4 --network name=en0 20.04

multipass launch -n localmachine -m 4G -d 50G -c 4 --network name=en0 20.04
```

## Provision the `'openbalena'` VM

Download the `'provision_server.sh'` and `'provision_local_machine.sh'` scripts
from: https://gist.github.com/pdcastro/a684d53568f3b780f4c9e0c154d6bb37

Run the following multipass commands to copy the `'provision_server.sh'` script
from the host OS to the `'openBalena'` server VM and open a shell on it:

```sh
multipass transfer provision_local_machine.sh localmachine:

multipass exec openbalena bash
```

In that shell, execute the following commands.

```sh
# Set env vars
export OB_EMAIL=<your email address - openBalena admin username>
export OB_PASSWORD=<choose an openBalena admin password>
export OB_DOMAIN=<your openBalena internet domain name>

chmod +x ./provision_server.sh
sudo -E ./provision_server.sh
exit
```

## Provision the `'localmachine'` VM

Run the following multipass commands to copy the `provision_local_machine.sh`
and `openbalena.crt` files to the `'localmachine'` VM, and open a shell on it:

```sh
# copy 'ca.crt' from the server VM, save it as 'openbalena.crt'
multipass exec openbalena -- sudo cat /home/balena/open-balena/config/certs/root/ca.crt > openbalena.crt

# copy 'openbalena.crt' to the 'localmachine' VM
cat openbalena.crt | multipass exec localmachine -- sudo bash -c 'cat > /usr/local/share/ca-certificates/openbalena.crt'

multipass transfer provision_local_machine.sh localmachine:

multipass exec localmachine bash
```

In that `'localmachine'` VM shell, execute the following commands.

```sh
export OB_DOMAIN=<your openBalena domain name, or a dummy like 'open.balena'>
export OB_EMAIL=<your email address - openBalena admin username>
export OB_PASSWORD=<your openBalena admin password>
export OB_SERVER_IP=<openbalena VM IP address, or the word 'skip'>
export CERT_PATH=/usr/local/share/ca-certificates/openbalena.crt

chmod +x ./provision_local_machine.sh
sudo -E ./provision_local_machine.sh
exit # important so that 'usermod' commands take effect
```

Test the installation with some balena CLI commands executed on the
`'localmachine'` VM:

```sh
multipass exec localmachine bash

balena version -a
balena settings
balena login
balena whoami
balena app create myApp --type raspberrypi3
balena apps
```
