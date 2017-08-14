# Provision the Kubernetes Infrastructure

Kubernetes will be used to host the Nomad control plane including the following components:

* [Consul](https://www.consul.io/) 0.9.2
* [Vault](https://www.vaultproject.io/) 0.8.0
* [Nomad](https://www.nomadproject.io/) 0.6.0

## Provision a Kubernetes Cluster

A Kubernetes 1.7.3+ cluster is required to host the Nomad control plane components. Use the `gcloud` command to provision a three node Kubernetes cluster:

```
gcloud container clusters create nomad \
  --cluster-version 1.7.3 \
  --machine-type n1-standard-2 \
  --num-nodes 3
```

It can take several minutes to provision the Kubernetes cluster. Either wait for the above command to complete or use the `gcloud` command to monitor progress in a separate terminal:

```
gcloud container clusters list
```
```
NAME   ZONE           MASTER_VERSION  MASTER_IP      MACHINE_TYPE   NODE_VERSION  NUM_NODES  STATUS
nomad  us-central1-f  1.7.3           XX.XXX.XXX.XX  n1-standard-2  1.7.3         3          PROVISIONING
```

> Estimated time to completion: 5 minutes.

```
gcloud container clusters list
```
```
NAME   ZONE           MASTER_VERSION  MASTER_IP      MACHINE_TYPE   NODE_VERSION  NUM_NODES  STATUS
nomad  us-central1-f  1.7.3           XX.XXX.XXX.XX  n1-standard-2  1.7.3         3          RUNNING
```

### Provision a Vault Node Pool

Add an additional node pool to support running Vault on a dedicated set of machines. Running Vault under single tenancy is [recommended for production](https://www.vaultproject.io/guides/production.html).

```
gcloud container node-pools create vault-pool \
  --cluster nomad \
  --machine-type n1-standard-2 \
  --num-nodes 2 \
  --node-labels dedicated=vault
```

> Estimated time to completion: 2 minutes.

List the node pools for the `nomad` Kubernetes cluster:

```
gcloud container node-pools list --cluster nomad
```
```
NAME          MACHINE_TYPE   DISK_SIZE_GB  NODE_VERSION
default-pool  n1-standard-2  100           1.7.3
vault-pool    n1-standard-2  100           1.7.3
```

It can take several minutes before the `nomad` Kubernetes cluster is ready. Use the `gcloud` command to monitor progress:

```
gcloud container clusters list
```

```
NAME   ZONE           MASTER_VERSION  MASTER_IP      MACHINE_TYPE   NODE_VERSION  NUM_NODES  STATUS
nomad  us-central1-f  1.7.3           XXX.XXX.XX.XX  n1-standard-2  1.7.3         5          RECONCILING
```

> Estimated time to completion: 3 minutes.

```
gcloud container clusters list
```

```
NAME   ZONE           MASTER_VERSION  MASTER_IP      MACHINE_TYPE   NODE_VERSION  NUM_NODES  STATUS
nomad  us-central1-f  1.7.3           XXX.XXX.XX.XX  n1-standard-2  1.7.3         5          RUNNING
```

### Taint the Vault Node Pool

Ensure the nodes in the `vault-pool` node pool only accept Vault workloads by [tainting](https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#taints-and-tolerations-beta-feature) them:

```
kubectl taint nodes \
  $(kubectl get nodes -l dedicated=vault -o jsonpath={.items[*].metadata.name}) \
  dedicated=vault:NoSchedule
```

### Configure Firewall Rules

Access to all components will be secured using TLS mutual authentication but caution should be taken to limit remote access to a limited set of IP address ranges. This tutorial permits access from anywhere to make things easier to follow.

Enable access to the Consul cluster from anywhere:

```
gcloud compute firewall-rules create default-allow-consul \
  --allow tcp:8300,udp:8301-8302,tcp:8301-8302,tcp:8500,tcp:8600,udp:8600 \
  --description "Allow consul from anywhere"
```

Enable access to the Nomad server from anywhere:

```
gcloud compute firewall-rules create default-allow-nomad \
  --allow tcp:4646-4647 \
  --description "Allow consul from anywhere"
```

Enable access to the Vault server from anywhere:

```
gcloud compute firewall-rules create default-allow-vault \
  --allow tcp:8200-8201 \
  --description "Allow vault from anywhere"
```

Next: [Provision The Nomad Infrastructure](04-nomad-infrastructure.md)
