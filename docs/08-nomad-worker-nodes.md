# Nomad Worker Nodes

Nomad workers are responsible for running Nomad Jobs. Each Nomad worker must have the Nomad agent installed and registered with the Nomad servers. The Nomad workers will be provisioned on a dedicated set of machines. While the Nomad servers can run inside of containers, managed by Kubernetes, the Nomad workers should not be, for practical reasons.

## Provision the Nomad Worker Instance Group

An [instance group](https://cloud.google.com/compute/docs/instance-groups/) will be used to manage the Nomad workers. Each Nomad worker will be provisioned from an [instance template](https://cloud.google.com/compute/docs/instance-groups/#instance_templates) to ensure consistency.

### Create the Nomad Instance Template

The Consul internal IP address and gossip encryption key are required to configure the Consul agent running on each Nomad worker instance. Consul provides service discovery for Nomad agents and Jobs.

Retrieve the Consul gossip encryption key:

```
GOSSIP_ENCRYPTION_KEY=$(cat ~/.gossip_encryption_key)
```

Retrieve the Consul internal IP address:

```
CONSUL_INTERNAL_IP=$(kubectl get svc consul-internal-load-balancer \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
```

Create the Nomad instance template:

```
gcloud compute instance-templates create nomad-instance-template \
  --boot-disk-size 200GB \
  --can-ip-forward \
  --image-family ubuntu-1604-lts \
  --image-project ubuntu-os-cloud \
  --machine-type n1-standard-1 \
  --metadata "gossip-encryption-key=${GOSSIP_ENCRYPTION_KEY},consul-internal-ip=${CONSUL_INTERNAL_IP}" \
  --metadata-from-file "startup-script=nomad.sh,ca-cert=ca.pem,consul-cert=consul.pem,consul-key=consul-key.pem,nomad-cert=nomad.pem,nomad-key=nomad-key.pem" \
  --scopes default,compute-ro \
  --tags nomad
```

At this point Nomad workers can be provisioned from the `nomad-instance-template` instance template.

### Create the Nomad Managed Instance Group

A [managed instance group](https://cloud.google.com/compute/docs/instance-groups/#managed_instance_groups) will be used to create a group of identical Nomad worker instances.

Create the `nomad` managed instance group:

```
gcloud compute instance-groups managed create nomad \
  --base-instance-name nomad \
  --size 1 \
  --template nomad-instance-template
```

> A single Nomad worker is being provisioned to control cost. Increase the number given to the `--size` flag for more instances.

It can take a few minutes to provision the Nomad worker instances. Use the `gcloud` command to monitor progress:

```
gcloud compute instance-groups list-instances nomad
```
```
NAME        ZONE           STATUS
nomad-XXXX  us-central1-f  RUNNING
```

> Estimated time to completion: 2 minutes.

> While the VMs will start running in as little as 30 seconds it will take up to 2 minutes before the nomad and consul services are configured and running.

## Check the Nomad Node Status

The Nomad client can be used to check the status of the Nomad worker nodes, but it must be configured with the Nomad cluster details. This can be done by setting the following environment variables:

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

Check the status of the Nomad worker nodes:

```
nomad node-status
```

```
ID        DC   Name        Class   Drain  Status
XXXXXXXX  dc1  nomad-XXXX  <none>  false  ready
```

At this point the Nomad cluster is ready to accept and run Nomad Jobs.

Next: [Running Nomad Jobs](09-nomad-jobs.md)
