#!/usr/bin/env bash

# Provision an Ubuntu or similar system as an openBalena "local machine"
# Tested with Ubuntu 20.04 LTS

set -eo pipefail # quit this script on errors

CERT_PATH="/usr/local/share/ca-certificates/openbalena.crt"
INSTALL_DIR="/opt"
CLI_BIN_PATH="/usr/local/bin/balena"
CLI_DIR="${INSTALL_DIR}/balena-cli"
CLI_CONFIG=~/.balenarc.yml

if [ `whoami` != root ]; then
  echo "This script must be executed as the root user (e.g. using 'sudo'). Aborting."
  exit 1
fi

if [ -z "${OB_DOMAIN}" ]; then
   echo 'OB_DOMAIN not set. Aborting.'
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

if [ -z "${OB_SERVER_IP}" ]; then
  cat <<EOF
OB_SERVER_IP environment variable must be set. If you have setup proper CNAME
records, please set this variable to 'skip'. Otherwise, set it to the IP address
of the openBalena server, and this script will update '/etc/hosts' for local name
resolution on this machine.
EOF
  exit 1
fi

if [ ! -r "${CERT_PATH}" ]; then
  cat <<EOF
'${CERT_PATH}' file not found or not readable. Aborting.
Please copy and rename the openBalena server's 'ca.crt' file to that location.
Hint: on the openBalena server, the file is typically found at:
'/home/balena/open-balena/config/certs/root/ca.crt'
EOF
   exit 1
fi

echo
echo "Installing dependencies..."
apt-get update && apt-get install -qy curl unzip docker.io

echo
if [ -z "${SUDO_USER}" ]; then
  echo "SUDO_USER env var not set: skipping adding user to docker group"
else
  echo "Adding current user '${SUDO_USER}' to 'docker' and 'sudo' groups..."
  usermod -aG sudo "${SUDO_USER}"
  usermod -aG docker "${SUDO_USER}"
fi

echo
echo "Installing the balena CLI to ${CLI_DIR}..."
mkdir -p "${INSTALL_DIR}"
cd "${INSTALL_DIR}"

CLI_VERSION=$(curl -sSL https://github.com/balena-io/balena-cli/releases/latest | sed -En 's/.*balena-cli-(v[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})-linux-x64-standalone\.zip.*/\1/p' | head -1)
CLI_ZIP_FILE="balena-cli-${CLI_VERSION}-linux-x64-standalone.zip"

echo
echo "Downloading CLI version ${CLI_VERSION}..."

if [ ! -e "${CLI_ZIP_FILE}" ]; then
  curl -LO "https://github.com/balena-io/balena-cli/releases/download/${CLI_VERSION}/${CLI_ZIP_FILE}"
fi
unzip -o "${CLI_ZIP_FILE}"

rm -f "${CLI_BIN_PATH}"
cat >"${CLI_BIN_PATH}" <<EOF
#!/usr/bin/env sh
export NODE_EXTRA_CA_CERTS=\${NODE_EXTRA_CA_CERTS:-"${CERT_PATH}"}
"${CLI_DIR}"/balena "\$@"
EOF
chmod +x "${CLI_BIN_PATH}"

echo
echo "Setting balenaUrl to '${OB_DOMAIN}' in '${CLI_CONFIG}'"
echo "balenaUrl: '${OB_DOMAIN}'" > "${CLI_CONFIG}"

echo
echo "Updating certificates..."
echo "Using '${CERT_PATH}' as the openBalena CA certificate"
chmod +r "${CERT_PATH}"
update-ca-certificates

echo
echo "Restarting Docker to take new certificates into account..."
systemctl restart docker

if [ -n "${OB_SERVER_IP}" -a "${OB_SERVER_IP}" != "skip" ]; then
  echo
  echo "Updating /etc/hosts..."
  cat <<EOF
Please note that this script is not yet smart enough to update existing
entries in '/etc/hosts', and will simply append new entries at the bottom.
You may need to tidy it up manually - sorry!
EOF
  cat >>/etc/hosts <<EOF
${OB_SERVER_IP}  api.open.balena
${OB_SERVER_IP}  registry.open.balena
${OB_SERVER_IP}  s3.open.balena
${OB_SERVER_IP}  tunnel.open.balena
${OB_SERVER_IP}  vpn.open.balena
EOF
fi

echo
echo "All done!"
