#!/usr/bin/env bash

export PATH=$PATH:/usr/local/bin

VAULT_VERSION="${VAULT_VERSION:-1.1.0}"
ENTERPRISE="${ENTERPRISE:false}"

echo "Installing Vault enterprise version ..."
cp /vagrant/ent/vault-enterprise_*.zip ./vault.zip

sudo apt-get install unzip

unzip vault.zip
chown root:root vault
chmod 0755 vault
mv vault /usr/local/bin
rm -f vault.zip

echo "Creating Vault service account ..."
useradd -r -d /etc/vault -s /bin/false vault

echo "Creating directory structure ..."
mkdir -p /etc/vault/pki
chown -R root:vault /etc/vault
chmod -R 0750 /etc/vault

mkdir /var/{lib,log}/vault
chown vault:vault /var/{lib,log}/vault
#chmod 0/Users/baljeetsingh/Desktop/VaultRepos/VaultGCPKms/vault-guides/operations/gcp-kms-unseal/terraform.tfvars.example750 /var/{lib,log}/vault

echo "Creating Vault configuration ..."
echo 'export VAULT_ADDR="http://localhost:8200"' | tee /etc/profile.d/vault.sh

NETWORK_INTERFACE=$(ls -1 /sys/class/net | grep -v lo | sort -r | head -n 1)
IP_ADDRESS=$(ip address show $NETWORK_INTERFACE | awk '{print $2}' | egrep -o '([0-9]+\.){3}[0-9]+')
HOSTNAME=$(hostname -s)

mkdir ./vault1.4RC1
chmod -R 777 vault1.4RC1

tee /etc/vault/vault.hcl << EOF
api_addr = "https://${IP_ADDRESS}:8200"
cluster_addr = "https://${IP_ADDRESS}:8201"
ui = true
storage "raft" {
  path    = "/home/vagrant/vault1.4RC1"
  node_id = "${IP_ADDRESS}"
}
listener "tcp" {
  address       = "0.0.0.0:8200"
  cluster_addr  = "${IP_ADDRESS}:8201"
  tls_disable   = "true"
}

EOF

chown root:vault /etc/vault/vault.hcl
chmod 0640 /etc/vault/vault.hcl
tee /etc/systemd/system/vault.service << EOF
[Unit]
Description="Vault secret management tool"
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/vault/vault.hcl
[Service]
User=vault
Group=vault
PIDFile=/var/run/vault/vault.pid
ExecStart=/usr/local/bin/vault server -config=/etc/vault/vault.hcl -log-level="trace" 
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=42
TimeoutStopSec=30
StartLimitInterval=60
StartLimitBurst=3
LimitNOFILE=65536
LimitMEMLOCK=infinity
[Install]
WantedBy=multi-user.target
EOF


systemctl daemon-reload
systemctl enable vault
systemctl restart vault
