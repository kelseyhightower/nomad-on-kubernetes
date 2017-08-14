# Provision The Nomad Infrastructure

In this section the TLS certificates, encryption tokens, and networking stack will be setup and configured for the Nomad control plane.

## Create the Kubernetes Services

The Nomad control plane is composed of services that need to be exposed inside and outside the Kubernetes cluster:

* `consul` - A [headless service](https://kubernetes.io/docs/concepts/services-networking/service/#headless-services) that exposes Consul inside the Kubernetes cluster.
* `consul-dns` - A [service](https://kubernetes.io/docs/concepts/services-networking/service/) that exposes the Consul DNS server inside the Kubernetes cluster.
* `consul-internal-load-balancer` - A service that exposes Consul behind an [internal load balancer](https://kubernetes.io/docs/concepts/services-networking/service/#internal-load-balancer).
* `nomad` - A service that exposes Nomad behind an [external load balancer](https://kubernetes.io/docs/concepts/services-networking/service/#type-loadbalancer).
* `vault` - A service that exposes Vault behind an external load balancer.

Create the Nomad services:

```
kubectl apply -f services
```

```
service "consul-dns" created
service "consul-internal-load-balancer" created
service "consul" created
service "nomad" created
service "vault" created
```

It can take several minutes for the internal and external load balancers to provision. Use the `kubectl` command to monitor progress:

```
kubectl get services
```

```
NAME                            CLUSTER-IP      EXTERNAL-IP    PORT(S)                                                                         
consul                          None            <none>         8600/TCP,8600/UDP,8500/TCP,8443/TCP,8301/TCP,8301/UDP,8302/TCP,8302/UDP,8300/TCP
consul-dns                      XX.XX.XXX.XX    <none>         53/TCP,53/UDP
consul-internal-load-balancer   XX.XX.XXX.XXX   XX.XXX.X.X     8500:30401/TCP,8443:30573/TCP,8301:31797/TCP,8300:31141/TCP
kubernetes                      XX.XX.XXX.X     <none>         443/TCP
nomad                           XX.XX.XXX.XXX   <pending>      4646:32740/TCP,4647:31583/TCP
vault                           XX.XX.XXX.XXX   <pending>      8200:31968/TCP,8201:31817/TCP
```

> Estimated time to completion: 3 minutes.

```
kubectl get services
```

```
NAME                            CLUSTER-IP      EXTERNAL-IP    PORT(S)                                                                         
consul                          None            <none>         8600/TCP,8600/UDP,8500/TCP,8443/TCP,8301/TCP,8301/UDP,8302/TCP,8302/UDP,8300/TCP
consul-dns                      XX.XX.XXX.XX    <none>         53/TCP,53/UDP
consul-internal-load-balancer   XX.XX.XXX.XXX   XX.XXX.X.X     8500:30401/TCP,8443:30573/TCP,8301:31797/TCP,8300:31141/TCP
kubernetes                      XX.XX.XXX.X     <none>         443/TCP
nomad                           XX.XX.XXX.XXX   XX.XXX.XXX.X   4646:32740/TCP,4647:31583/TCP
vault                           XX.XX.XXX.XXX   XX.XXX.XX.XXX  8200:31968/TCP,8201:31817/TCP
```

Do not continue until the above Nomad services have obtained an external IP address.

## Create the Kubernetes Secrets

Communication and authentication between the Nomad control plane components are protected by TLS mutual authentication. Each set of components will use a separate TLS certificate. To ensure valid certificates are created the external IP address of each service is required.

Set the namespace:  

```
NAMESPACE="default"
```

Retrieve the `consul-internal-load-balancer` service `EXTERNAL-IP` address:

```
CONSUL_INTERNAL_IP=$(kubectl get svc consul-internal-load-balancer \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
```

Retrieve the `nomad` service `EXTERNAL-IP` address:

```
NOMAD_EXTERNAL_IP=$(kubectl get svc nomad \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
```

Retrieve the `vault` service `EXTERNAL-IP` address:

```
VAULT_EXTERNAL_IP=$(kubectl get svc vault \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
```

### Setup PKI Infrastructure

Before we can generate TLS certificates for each Nomad component we need to setup a Certificate Authority.

Generate the CA certificate:

```
cfssl gencert -initca ca/ca-csr.json | cfssljson -bare ca
```

With the Certificate Authority in place we are now ready to generate TLS certificates for Consul, Vault, and Nomad.

Generate the Consul TLS certificate and private key:

```
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca/ca-config.json \
  -hostname="consul,consul.${NAMESPACE}.svc.cluster.local,localhost,server.dc1.consul,127.0.0.1,${CONSUL_INTERNAL_IP}" \
  -profile=default \
  ca/consul-csr.json | cfssljson -bare consul
```

Generate the Vault TLS certificate and private key:

```
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca/ca-config.json \
  -hostname="vault,vault.${NAMESPACE}.svc.cluster.local,localhost,vault.dc1.consul,vault.service.consul,127.0.0.1,${VAULT_EXTERNAL_IP}" \
  -profile=default \
  ca/vault-csr.json | cfssljson -bare vault
```

Combine the Vault and CA certificates:

```
cat vault.pem ca.pem > vault-combined.pem
```

Generate the Nomad TLS certificate and private key:

```
cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca/ca-config.json \
  -hostname="localhost,client.global.nomad,nomad,nomad.${NAMESPACE}.svc.cluster.local,global.nomad,server.global.nomad,127.0.0.1,${NOMAD_EXTERNAL_IP}" \
  -profile=default \
  ca/nomad-csr.json | cfssljson -bare nomad
```

### Generate a Consul Gossip Encryption Key

Use the `consul` command to generate a gossip encryption key:

```
GOSSIP_ENCRYPTION_KEY=$(consul keygen)
```

Save the gossip encryption key to a file for later use:

```
echo $GOSSIP_ENCRYPTION_KEY > ~/.gossip_encryption_key
```

### Create the Kubernetes Secrets

At this point we are ready to create the Kubernetes secrets where the TLS certificates and the Consul gossip encryption key will be stored.

Create the `consul` secret:

```
kubectl create secret generic consul \
  --from-literal="gossip-encryption-key=${GOSSIP_ENCRYPTION_KEY}" \
  --from-file=ca.pem \
  --from-file=consul.pem \
  --from-file=consul-key.pem
```

Create the `vault` secret:

```
kubectl create secret generic vault \
  --from-file=ca.pem \
  --from-file=vault.pem=vault-combined.pem \
  --from-file=vault-key.pem
```

Create the `nomad` secret:

```
kubectl create secret generic nomad \
  --from-file=ca.pem \
  --from-file=nomad.pem \
  --from-file=nomad-key.pem
```

Use the `kubectl` command to verify the secrets have been created:

```
kubectl get secrets
```
```
NAME                  TYPE                                  DATA      AGE
consul                Opaque                                4         23s
default-token-XXXXX   kubernetes.io/service-account-token   3         32m
nomad                 Opaque                                3         13s
vault                 Opaque                                3         18s
```

Next: [Provision The Consul Cluster](05-consul.md)
