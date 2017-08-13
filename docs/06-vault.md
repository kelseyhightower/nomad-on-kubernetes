# Vault

Vault provides secrets management in a Nomad cluster and will be deployed as part of the Nomad control plane.

## Deploy the Vault StatefulSet

Vault will be configured to store its state in the Consul cluster setup in the previous section. A StatefulSet is being used to ensure each Vault instance receives a stable DNS name and to provide stable storage for the local consul instance running as a side-car.

Create the Vault ConfigMap and store the Vault configuration file:

```
kubectl apply -f configmaps/vault.yaml
```

Create the `vault` StatefulSet:

```
kubectl apply -f statefulsets/vault.yaml
```

It can take almost a minute before the `vault` cluster is ready. Use `kubectl` to monitor progress:

```
kubectl get pods -l app=vault
```
```
NAME       READY     STATUS              RESTARTS   AGE
vault-0    0/2       ContainerCreating   0          7s
```

> Estimated time to completion: 1 minute.

```
kubectl get pods -l app=vault
```
```
NAME       READY     STATUS    RESTARTS   AGE
vault-0    2/2       Running   0          33s
```

## Initialize Vault

Before Vault can be used to manage secrets it must be [initialized](https://www.vaultproject.io/intro/getting-started/deploy.html#initializing-the-vault) and [unsealed](https://www.vaultproject.io/docs/concepts/seal.html).

The Vault client can be used to initialize and unseal the remote Vault cluster, but it must be configured with the remote Vault cluster details. This can be done by setting the following environment variables:

```
VAULT_ADDR
VAULT_CACERT
VAULT_CLIENT_CERT
VAULT_CLIENT_KEY
```

Source the `vault.env` shell script to populate the necessary environment variables for the current shell session:

```
source vault.env
```

Check the current status of the remote Vault cluster:

```
vault status
```

```
Error checking seal status: Error making API request.

URL: GET https://XX.XXX.XXX.XX:8200/v1/sys/seal-status
Code: 400. Errors:

* server is not yet initialized
```

The above error indicates the Vault cluster needs to be initialized. Initialize the remote Vault cluster:

```
vault init
```

```
Unseal Key 1: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
Unseal Key 2: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
Unseal Key 3: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
Unseal Key 4: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
Unseal Key 5: XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
Initial Root Token: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX

Vault initialized with 5 keys and a key threshold of 3. Please
securely distribute the above keys. When the vault is re-sealed,
restarted, or stopped, you must provide at least 3 of these keys
to unseal it again.

Vault does not store the master key. Without at least 3 keys,
your vault will remain permanently sealed.
```

Save the five unseal keys and the initial root token.

### Unseal the Remote Vault Instance

Unseal the remote Vault instance using three of the unseal keys:

```
vault unseal
```

```
Key (will be hidden):
Sealed: true
Key Shares: 5
Key Threshold: 3
Unseal Progress: 1
Unseal Nonce: XXXXXXXX-XXXX-XXX-XXX-XXXXXXXXXXXX
```

Repeat the unseal command two more times. Once completed the `Sealed` status will be set to `false`:

```
vault unseal
```
```
Key (will be hidden):
Sealed: false
Key Shares: 5
Key Threshold: 3
Unseal Progress: 0
Unseal Nonce:
```

Review the status of the remote Vault cluster:

```
vault status
```

```
Sealed: false
Key Shares: 5
Key Threshold: 3
Unseal Progress: 0
Unseal Nonce:
Version: 0.8.0
Cluster Name: vault-cluster-XXXXXXXX
Cluster ID: XXXXXXXX-XXXX-XXX-XXX-XXXXXXXXXXXX

High-Availability Enabled: true
	Mode: active
	Leader Cluster Address: https://XX.X.X.X:8201
```

At this point the remote Vault cluster has been initialized and is ready for use.

Login the remote Vault cluster using the initial root token:

```
vault auth
```

```
Token (will be hidden):
Successfully authenticated! You are now logged in.
token: XXXXXXXX-XXXX-XXX-XXX-XXXXXXXXXXXX
token_duration: 0
token_policies: [root]
```

> Enter the initial root token at the prompt.

## Create Nomad Root Token

Nomad has native [Vault integration](https://www.nomadproject.io/docs/vault-integration/index.html) which requires a role based Vault token.

### Create the Nomad Role Based Vault Token

```
vault policy-write nomad-server nomad-server-policy.hcl
```

```
vault write /auth/token/roles/nomad-cluster @nomad-cluster-role.json
```

### Update the Nomad Kubernetes Secret

Generate a new role based Vault token:

```
NOMAD_VAULT_TOKEN=$(vault token-create \
  -policy nomad-server \
  -period 72h \
  -orphan \
  -format json | tee ~/.nomad-vault-token | jq -r '.auth.client_token')
```

Update the `nomad` Kubernetes secret and append the `vault-token` secret:

```
kubectl create secret generic nomad \
  --from-file=ca.pem \
  --from-file=nomad.pem \
  --from-file=nomad-key.pem \
  --from-literal=vault-token=${NOMAD_VAULT_TOKEN} -o yaml --dry-run | \
  kubectl replace -f -
```

Review the `nomad` Kubernetes secret and verify the presence of the `vault-token` key and value:

```
kubectl describe secret nomad
```

```
Name:           nomad
Namespace:      default
Labels:         <none>
Annotations:    <none>

Type:           Opaque

Data
====
ca.pem:         1261 bytes
nomad-key.pem:  1675 bytes
nomad.pem:      1562 bytes
vault-token:    36 bytes
```

The Vault cluster is now ready for use by the Nomad control plane.

> Note: If the Vault server is ever restarted it must be [unsealed](#unseal-the-remote-vault-instance).
