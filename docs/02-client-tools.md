# Install Client Tools

This tutorial requires interacting with a number of tools and services which require a specific set of command line utilities to be installed on the machine used to follow this tutorial.

Install the following client tools and ensure they are in your path:

* [cfssl](https://github.com/cloudflare/cfssl) 1.2.0
* [cfssljson](https://github.com/cloudflare/cfssl) 1.2.0
* [consul](https://www.consul.io/downloads.html) 0.9.3
* [nomad](https://www.nomadproject.io/downloads.html) 0.6.3
* [vault](https://www.vaultproject.io/downloads.html) 0.8.2
* [gcloud](https://cloud.google.com/sdk/) 171.0.0
* [kubectl](https://cloud.google.com/sdk/docs/components) 1.7.5
* [jq](https://stedolan.github.io/jq/download/) 1.5

> Install kubectl using gcloud: gcloud components install kubectl

Configure default zone and project in in gcloud:

`gcloud config set compute/zone <zone>` ([Google Cloud Regions and Zones](https://cloud.google.com/compute/docs/regions-zones/regions-zones))

`gcloud projects create k8snomad --name Nomad`
`gcloud config set project k8snomad`

Next: [Provision The Kubernetes Infrastructure](03-kubernetes-infrastructure.md)
