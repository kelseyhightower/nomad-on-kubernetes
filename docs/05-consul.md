# Consul

Consul is a distributed key/value store that provides service discovery and health checking in a Nomad cluster. In this section three Consul servers will be deployed as part of the Nomad control plane.

## Provision the Consul Servers

Consul will be configured to store cluster state on network attached volumes. The network attached volumes will be dynamically provisioned and managed by Kubernetes.

Create the `consul` ConfigMap which holds the Consul server and client configuration:

```
kubectl apply -f configmaps/consul.yaml
```

Create the `consul` StatefulSet which will manage the Consul servers and ensure they have stable storage and DNS names:

```
kubectl apply -f statefulsets/consul.yaml
```

It will take a few minutes to provision the Consul cluster. Use the `kubectl` command to monitor progress:

```
kubectl get pods -l app=consul
```
```
NAME       READY     STATUS    RESTARTS   AGE
consul-0   0/1       Pending   0          5s
```

> Estimated time to completion: 2 minutes.

```
kubectl get pods
```

```
NAME       READY     STATUS    RESTARTS   AGE
consul-0   1/1       Running   0          1m
consul-1   1/1       Running   0          1m
consul-2   1/1       Running   0          39s
```

### Delegate the consul domain to Consul

The internal Kubernetes DNS service can be configure to delegate specific domains to another DNS server such as Consul. This enables Consul to handle all DNS queries to the `consul.` domain, while Kubernetes handles everything else.

```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-dns
  namespace: kube-system
data:
  stubDomains: |
    {"consul": ["$(kubectl get svc consul-dns -o jsonpath='{.spec.clusterIP}')"]}
EOF
```

Next: [Provision The Vault Service](06-vault.md)
