#!/usr/bin/env bash

# Provision an Ubuntu or similar system as an openBalena server
# Tested with Ubuntu 20.04 LTS

set -eo pipefail # quit this script on errors

DOCKER_COMPOSE="/usr/local/bin/docker-compose"

if [[ -z "${OB_EMAIL}" || -z "${OB_PASSWORD}" || -z "${OB_DOMAIN}" ]]; then
   echo 'OB_EMAIL, OB_PASSWORD or OB_DOMAIN env vars not set. Aborting.'
   exit 1
fi

if [[ "${OB_DOMAIN}" = *.local ]]; then
  cat <<EOF
Using a '.local' domain name (${OB_DOMAIN}) for openBalena is known to cause
name resolution problems and spurious errors. For experiments not involving
balenaOS devices, a dummy domain name like 'open.balena' can be used. To test
with balenaOS device, use a real internet domain name with a public IP address,
or alternatively setup a local DNS and DHCP server like dnsmasq that could
map dummy hostnames to private IP addresses. (A local DHCP server is also
needed because balenaOS devices always include the DNS servers advertised
by DHCP to a pool of available DNS servers, even when alternative DNS servers
are configured in the device's 'config.json' file.)
Aborting.
EOF
  exit 1
fi

if [ `whoami` != root ]; then
  echo "This script must be executed as the root user (e.g. using 'sudo'). Aborting."
  exit 1
fi

echo
echo "Installing dependencies..."
apt-get update && apt-get install -qy build-essential git docker.io libssl-dev nodejs

if [[ ! -e "${DOCKER_COMPOSE}" ]]; then
  curl -L https://github.com/docker/compose/releases/download/1.27.4/docker-compose-Linux-x86_64 -o "${DOCKER_COMPOSE}"
  chmod +x "${DOCKER_COMPOSE}"
fi

echo
echo "Starting Docker..."
systemctl start docker

echo
echo "Creating 'balena' user account..."
adduser --disabled-password --gecos "" balena || true
usermod -aG sudo balena
usermod -aG docker balena

echo
echo "Installing openBalena..."
cd /home/balena
sudo -u balena git clone https://github.com/balena-io/open-balena.git
cd /home/balena/open-balena
sudo -u balena /home/balena/open-balena/scripts/quickstart -U "${OB_EMAIL}" -P "${OB_PASSWORD}" -d "${OB_DOMAIN}"

echo 'All done. To start openBalena, run:'
echo 'sudo su - balena'
echo '/home/balena/open-balena/scripts/compose up -d'
