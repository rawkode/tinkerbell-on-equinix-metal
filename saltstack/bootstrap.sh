#!/usr/bin/env sh
curl -fsSL -o /usr/share/keyrings/salt-archive-keyring.gpg https://repo.saltproject.io/py3/ubuntu/20.04/amd64/3003/salt-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/salt-archive-keyring.gpg] https://repo.saltproject.io/py3/ubuntu/20.04/amd64/3003 focal main" | tee /etc/apt/sources.list.d/salt.list

DEBIAN_FRONTEND=noninteractive apt update && apt install --yes salt-master salt-minion

cat <<EOF >/etc/salt/master.d/master.conf
autosign_grains_dir: /etc/salt/autosign-grains
fileserver_backend:
  - roots
  - gitfs

gitfs_remotes:
  - https://github.com/rawkode/tinkerbell-on-equinix-metal:
      - root: saltstack/states
      - base: main
      - update_interval: 600

ext_pillar:
  - http_json:
      url: https://metadata.platformequinix.com/metadata
EOF

AUTOSIGN_KEY=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

cat <<EOF >/etc/salt/minion.d/minion.conf
autosign_grains:
- localsign-key

startup_states: highstate

schedule:
  highstate:
    function: state.highstate
    minutes: 15

grains:
  localsign-key: ${AUTOSIGN_KEY}
EOF


PRIVATE_IPV4=$(curl -s https://metadata.platformequinix.com/metadata | jq -r '.network.addresses | map(select(.public==false)) | first | .address')
echo interface: ${PRIVATE_IPV4} > /etc/salt/master.d/private-interface.conf
echo master: ${PRIVATE_IPV4} > /etc/salt/minion.d/master.conf

mkdir -p /etc/salt/autosign-grains/
echo -e "${AUTOSIGN_KEY}\n" > /etc/salt/autosign-grains/localsign-key

systemctl daemon-reload
systemctl enable salt-master.service
systemctl restart --no-block salt-master.service
systemctl enable salt-minion.service
systemctl restart --no-block salt-minion.service
