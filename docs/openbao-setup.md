# Setting Openbao for Secret Management

## What is Openbao ?

Openbao is an open-source fork of Hashicorp Vault under MPL 2.0 that aims to manage, store, and distribute sensitive data (i.e., secrets).

## Create an Openbao instance

My main usage for Openbao is for workloads that will run within Kubernetes.

As my cluster may be recreated multiple times, I made the choice to run Openbao in a Proxmox LXC in a new and dedicated Opnsense subnet.

### Pre-requisites

* Deploying Opnsense and as of now using local state as data
* Opnsense certificate and private key for `openbao.internal` domain (see [Generate a server certificate](./opnsense-certificate-authority.md#generate-a-server-certificate))
* Applying project in `iac/opentofu/platform`, which:
    * Deploy a Debian 13 Proxmox LXC
    * Add a dedicated SSH key to connect to the container
    * Creates a static IP for openbao
    * Creates an unbound DNS override on `openbao.internal`
* Network reachability to openbao LXC (in my case its thanks to [enabling WireGuard VPN](./proxmox-packer-execution.md#enable-wireguard-vpn-optional))

### Configuring Openbao LXC

To apply the platform project you must set the following environment variables:
```bash
PROXMOX_VE_ENDPOINT=
PROXMOX_VE_API_TOKEN=

OPNSENSE_URI=
OPNSENSE_API_KEY=
OPNSENSE_API_SECRET=
```

Once defined, run this command from the `iac/opentofu/platform` directory:
```
tofu apply
```

Then retrieve the SSH private key from tofu outputs:
```bash
tofu output -raw platform_private_key > ~/.ssh/platform.pem && \
    chmod 400 ~/.ssh/platform.pem
```

Connect to the LXC:
```bash
OPENBAO_HOSTNAME=${tofu output -json platform_hostname | jq -r '.openbao'}
ssh -i ~/.ssh/platform.pem root@$OPENBAO_HOSTNAME
```

Download Openbao in the Debian 13 LXC:
```bash
apt update -y && \
    apt install -y curl

curl -LO https://github.com/openbao/openbao/releases/download/v2.5.2/openbao_2.5.2_linux_amd64.deb && \
    dpkg -i openbao_2.5.2_linux_amd64.deb
```

Create directories for Openbao and initialize required files:
```bash
mkdir -p /var/lib/openbao/data && \
    mkdir -p /etc/openbao/tls && \
    chown -R openbao:openbao /var/lib/openbao


cat > /etc/openbao/tls/server.crt <<EOF
$OPENBAO_CERTIFICATE
EOF

cat > /etc/openbao/tls/server.key <<EOF
$OPENBAO_PRIVATE_KEY
EOF

cat > /etc/openbao/config.hcl <<EOF
ui = true

storage "raft" {
  path    = "/var/lib/openbao/data"
  node_id = "node1"
}

listener "tcp" {
  address       = "0.0.0.0:443"
  cluster_address = "0.0.0.0:8201"
  tls_cert_file = "/etc/openbao/tls/server.crt"
  tls_key_file  = "/etc/openbao/tls/server.key"
}

api_addr     = "https://$OPENBAO_HOSTNAME:443"
cluster_addr = "https://$OPENBAO_HOSTNAME:8201"

log_level     = "info"
EOF
```

Start the openbao vault server:
```bash
bao server -config=/etc/openbao/config.hcl
```

In another terminal (adjust the unseal key number accordingly):
```bash
export BAO_ADDR='https://$OPENBAO_HOSTNAME'
bao operator init -key-shares=5 -key-threshold=3
```

You should have the unseal keys and the root token (`s.xxxxxxxxxxxxxxxxxxxxxxxx`).

Unseal the vault using the unseal keys 
```bash
export BAO_TOKEN='s.xxxxxxxxxxxxxxxxxxxxxxxx'
# Repeat with different unseal keys (based on '-key-threshold' value)
bao operator unseal $UNSEAL_KEY_X
```

### Create a systemd service to start openbao on boot

Create a system user and group to run the service
```bash
adduser openbao
```

Allow openbao binding on lower port for all users
```bash
setcap CAP_NET_BIND_SERVICE=+eip /usr/bin/bao
```

Create the systemd configuration for openbao
```bash
cat > /etc/systemd/system/bao.service <<EOF
[Unit]
Description="Openbao Secrets Vault"
After=network.target

[Service]
User=openbao
Group=openbao

ExecStart=/usr/bin/bao server -config=/etc/openbao/config.hcl

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

Reload systemd and enable the bao service on boot:
```bash
systemctl daemon-reload && \
  systemctl enable bao.service && \
  systemctl start bao.service
```

> [!NOTE] 
> Make sure you ran `chown -R openbao:openbao /var/lib/openbao` beforehand

### Create an AppRole for OpenTofu to manage Kubernetes access

Use a dedicated namespace for the Kubernetes cluster:
```bash
bao namespace create homelab
```

Enable AppRole in the namespace
```bash
bao auth enable -namespace=homelab -path=tofu approle
```

Create and apply a policy:
```bash
cat > homelab-policy.hcl <<EOF
# Manage ACL policies
path "sys/policies/acl/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage the Kubernetes Auth Config
path "auth/kubernetes/config" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Manage Kubernetes Roles
path "auth/kubernetes/role/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Manage auth methods
path "sys/auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage Secrets engines
path "sys/mounts/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Allow the Terraform provider to create child tokens
path "auth/token/create" {
  capabilities = ["update"]
}

# Manage PKI data
path "pki/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOF

# Create the policy
bao policy write -namespace=homelab homelab-admin homelab-policy.hcl
```

Create the AppRole for OpenTofu with the `homelab-admin` policy
```bash
bao write -namespace=homelab auth/tofu/role/tofu \
    secret_id_ttl=24h \
    token_num_uses=0 \
    token_ttl=1h \
    token_max_ttl=3h \
    token_policies="homelab-admin"
```

Retrieve the role id:
```bash
bao read -namespace=homelab  auth/tofu/role/tofu/role-id
```

Generate a secret id:
```bash
bao write -namespace=homelab -f auth/tofu/role/tofu/secret-id
```

Enable KV on a path for kubernetes:
```bash
bao secrets enable -namespace homelab -path kubernetes/talos-cluster kv
```
