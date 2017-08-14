# Prerequisites

## Google Cloud Platform

This tutorial leverages the [Google Cloud Platform](https://cloud.google.com/) to streamline the provisioning of a Kubernetes cluster and the necessary compute infrastructure required to run a Nomad cluster. [Sign up](https://cloud.google.com/free/) for $300 in free credits.

[Estimated cost](https://cloud.google.com/products/calculator/#id=1dc8801f-7903-432c-8eb3-f3b73b10be4d) to run this tutorial: $0.43 per hour ($10.31 per day).

> The compute resources required for this tutorial exceed the Google Cloud Platform free tier.

## Source

This tutorial requires access to its source tree on the same machine where commands will be executed. Clone this repository:

```
git clone https://github.com/kelseyhightower/nomad-on-kubernetes.git
```

Move into the `nomad-on-kubernetes` directory:

```
cd nomad-on-kubernetes
```

Next: [Install Client Tools](02-client-tools.md)
