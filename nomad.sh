#!/bin/bash

CA_CERT=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/ca-cert)
CONSUL_CERT=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/consul-cert)
CONSUL_KEY=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/consul-key)
CONSUL_INTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/consul-internal-ip)
EXTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)
GOSSIP_ENCRYPTION_KEY=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/gossip-encryption-key)
NOMAD_CERT=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/nomad-cert)
NOMAD_KEY=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/nomad-key)

apt-get update
apt-get install -y wget unzip dnsmasq

## Download Consul
wget -O consul_1.2.0_linux_amd64.zip \
  https://releases.hashicorp.com/consul/1.2.0/consul_1.2.0_linux_amd64.zip

## Download Nomad
wget -O nomad_0.8.4_linux_amd64.zip \
  https://releases.hashicorp.com/nomad/0.8.4/nomad_0.8.4_linux_amd64.zip

## Install Consul and Nomad
unzip consul_1.2.0_linux_amd64.zip
unzip nomad_0.8.4_linux_amd64.zip

chmod +x consul nomad
mv consul nomad /usr/local/bin

rm consul_1.2.0_linux_amd64.zip nomad_0.8.4_linux_amd64.zip


## Configure and Start Consul
mkdir -p /etc/consul
mkdir -p /etc/consul/tls
mkdir -p /var/lib/consul

echo "${CA_CERT}" > /etc/consul/tls/ca.pem
echo "${CONSUL_CERT}" > /etc/consul/tls/consul.pem
echo "${CONSUL_KEY}" > /etc/consul/tls/consul-key.pem

cat > /etc/consul/agent.json <<EOF
{
  "ca_file": "/etc/consul/tls/ca.pem",
  "cert_file": "/etc/consul/tls/consul.pem",
  "key_file": "/etc/consul/tls/consul-key.pem",
  "verify_outgoing": true,
  "verify_server_hostname": true
}
EOF

cat > /etc/systemd/system/consul.service <<EOF
[Unit]
Description=Consul
Documentation=https://www.consul.io/docs

[Service]
ExecStart=/usr/local/bin/consul agent \\
  -config-file /etc/consul/agent.json \\
  -data-dir /var/lib/consul \\
  -encrypt ${GOSSIP_ENCRYPTION_KEY} \\
  -retry-join ${CONSUL_INTERNAL_IP}
ExecReload=/bin/kill -HUP $MAINPID
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl enable consul
systemctl start consul

## Setup dnsmasq

mkdir -p /etc/dnsmasq.d
cat > /etc/dnsmasq.d/10-consul.conf <<'EOF'
server=/consul/127.0.0.1#8600
EOF

systemctl enable dnsmasq
systemctl restart dnsmasq


## Configure and Start Nomad
mkdir -p /etc/nomad
mkdir -p /etc/nomad/tls
mkdir -p /var/lib/nomad

echo "${CA_CERT}" > /etc/nomad/tls/ca.pem
echo "${NOMAD_CERT}" > /etc/nomad/tls/nomad.pem
echo "${NOMAD_KEY}" > /etc/nomad/tls/nomad-key.pem

cat > /etc/nomad/client.hcl <<EOF
advertise {
  http = "${EXTERNAL_IP}:4646"
  rpc = "${EXTERNAL_IP}:4647"
}

bind_addr = "0.0.0.0"

client {
  enabled = true
  options {
    "driver.raw_exec.enable" = "1"
  }
}

data_dir = "/var/lib/nomad"
log_level = "DEBUG"

tls {
  ca_file = "/etc/nomad/tls/ca.pem"
  cert_file = "/etc/nomad/tls/nomad.pem"
  http = true
  key_file = "/etc/nomad/tls/nomad-key.pem"
  rpc = true
  verify_https_client = true
}

vault {
  address = "https://vault.service.consul:8200"
  ca_path = "/etc/nomad/tls/ca.pem"
  cert_file = "/etc/nomad/tls/nomad.pem"
  enabled = true
  key_file = "/etc/nomad/tls/nomad-key.pem"
}
EOF

cat > /etc/systemd/system/nomad.service <<'EOF'
[Unit]
Description=Nomad
Documentation=https://nomadproject.io/docs

[Service]
ExecStart=/usr/local/bin/nomad agent -config /etc/nomad/client.hcl
ExecReload=/bin/kill -HUP $MAINPID
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl enable nomad
systemctl start nomad
