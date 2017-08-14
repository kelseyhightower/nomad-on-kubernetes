# Nomad

Nomad schedules applications and services in a similar fashion to Kubernetes but does not require container images. Running Nomad in addition to Kubernetes broadens the types of workloads you can run. In this tutorial Nomad will be used to schedule [Jobs](https://www.nomadproject.io/docs/job-specification/index.html) onto a dedicated set of machines, outside of the `nomad` Kubernetes cluster, running Nomad agents.

> Kubernetes supports a wide range of workloads including batch and scheduled jobs, but workloads must be packaged and run as containers.

## Provision the Nomad Servers

Nomad will be configured to store the Nomad cluster state on network attached volumes. The network attached volumes will be dynamically provisioned and managed by Kubernetes. Nomad will be configured to use Consul for service discovery and Vault for secrets management. The Nomad servers will also have access to Kubernetes secrets and services to help streamline bootstrapping and ongoing management of the Nomad servers.

Create the `nomad` ConfigMap which holds the Nomad server configuration:

```
kubectl apply -f configmaps/nomad.yaml
```

Create the `nomad` StatefulSet which will manage Nomad servers and ensure they have stable storage and DNS names:

```
kubectl apply -f statefulsets/nomad.yaml
```

It can take a few minutes before the Nomad cluster is ready. Use the `kubectl` command to monitor progress:

```
kubectl get pods -l app=nomad
```
```
NAME      READY     STATUS              RESTARTS   AGE
nomad-0   0/2       ContainerCreating   0          8s
```

> Estimated time to completion: 2 minutes.

```
kubectl get pods -l app=nomad
```
```
NAME      READY     STATUS    RESTARTS   AGE
nomad-0   2/2       Running   0          1m
nomad-1   2/2       Running   0          1m
nomad-2   2/2       Running   0          40s
```

## Verify the Nomad Cluster

The Nomad client can be used to check the status of the Nomad cluster, but it must be configured with the Nomad cluster details. This can be done by setting the following environment variables:

```
NOMAD_ADDR
NOMAD_CACERT
NOMAD_CLIENT_CERT
NOMAD_CLIENT_KEY
```

Source the `nomad.env` shell script to populate the necessary environment variables for the current shell session:

```
source nomad.env
```

List the Nomad cluster server members:

```
nomad server-members
```

```
Name            Address   Port  Status  Leader  Protocol  Build  Datacenter  Region
nomad-0.global  XX.X.X.X  4648  alive   true    2         0.6.0  dc1         global
nomad-1.global  XX.X.X.X  4648  alive   false   2         0.6.0  dc1         global
nomad-2.global  XX.X.X.X  4648  alive   false   2         0.6.0  dc1         global
```

The Nomad cluster has been fully bootstrapped and is now ready for use.

Next: [Provision the Nomad Worker Nodes](08-nomad-worker-nodes.md)
