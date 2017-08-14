# Running Jobs on Nomad

With the Nomad servers and agents fully bootstrapped you now have the ability to submit and run [Jobs](https://www.nomadproject.io/docs/operating-a-job/index.html).

## Configure the Nomad Client

Before submitting Jobs the local Nomad client must be configure with the remote Nomad cluster details. This can be done by setting the following environment variables:

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

## Run the Example Jobs

There are two example Jobs under the jobs directory:

* `ping` - runs the ping command against the google.com domain.
* `token-printer` - loads a Vault token from a file and prints it to stderr.

### Run the ping Job

The `ping` Job runs the ping command against the google.com domain 1000 times then exits.

Execute a plan for the `ping` Job:

```
nomad plan jobs/ping.nomad
```

```
+ Job: "ping"
+ Task Group: "example" (1 create)
  + Task: "ping" (forces create)

Scheduler dry-run:
- All tasks successfully allocated.

Job Modify Index: 0
To submit the job with version verification run:

nomad run -check-index 0 jobs/ping.nomad

When running the job with the check-index flag, the job will only be run if the
server side version matches the job modify index returned. If the index has
changed, another user has modified the job and the plan's results are
potentially invalid.
```

Submit and run the `ping` Job:

```
nomad run jobs/ping.nomad
```

```
==> Monitoring evaluation "XXXXXXXX"
    Evaluation triggered by job "ping"
    Allocation "XXXXXXXX" created: node "XXXXXXXX", group "example"
    Evaluation status changed: "pending" -> "complete"
==> Evaluation "XXXXXXXX" finished with status "complete"
```

Check the status of the `ping` Job:

```
nomad status ping
```

```
ID            = ping
Name          = ping
Submit Date   = XX/XX/XX XX:XX:XX PDT
Type          = service
Priority      = 50
Datacenters   = dc1
Status        = running
Periodic      = false
Parameterized = false

Summary
Task Group  Queued  Starting  Running  Failed  Complete  Lost
example     0       0         1        0       0         0

Allocations
ID        Node ID   Task Group  Version  Desired  Status   Created At
XXXXXXXX  XXXXXXXX  example     0        run      running  XX/XX/XX XX:XX:XX PDT
```

Retrieve and view the logs for the `ping` Job:

```
nomad logs -job ping
```

```
PING google.com (XX.XXX.XX.XXX) 56(84) bytes of data.
64 bytes from XX-XX-XXXX.XXXXX.net (XX.XXX.XX.XXX): icmp_seq=1 ttl=53 time=1.01 ms
64 bytes from XX-XX-XXXX.XXXXX.net (XX.XXX.XX.XXX): icmp_seq=2 ttl=53 time=0.675 ms
64 bytes from XX-XX-XXXX.XXXXX.net (XX.XXX.XX.XXX): icmp_seq=3 ttl=53 time=0.621 ms
```

The `ping` Job is set to run continuously. After every successful run Nomad will automatically restart the Job.

Stop and purge the `ping` Job:

```
nomad stop -purge ping
```

```
==> Monitoring evaluation "XXXXXXXX"
    Evaluation triggered by job "ping"
    Evaluation status changed: "pending" -> "complete"
==> Evaluation "XXXXXXXX" finished with status "complete"
```

### Run the token printer Job

The `token-printer` Job demonstrates Nomad's native Vault integration. The `token-printer` Job specification requests a Vault token attached to the default Vault profile. The Nomad agent that accepts and runs the `token-printer` Job will populate a token in a file named `vault_token` under the running Job's secret directory. The `token-printer` job will continuously monitor the token file for changes while printing the current value to stderr.

Execute a plan for the `token-printer` Job:

```
nomad plan jobs/token-printer.nomad
```

Submit and run the `token-printer` Job:

```
nomad run jobs/token-printer.nomad
```

Retrieve and view the logs for the `token-printer` Job:

```
nomad logs -stderr -job token-printer
```

```
XXXX/XX/XX XX:XX:XX starting token-printer service...
XXXX/XX/XX XX:XX:XX current token value: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
XXXX/XX/XX XX:XX:XX current token value: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
XXXX/XX/XX XX:XX:XX current token value: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
```

The `token-printer` Job is set to run continuously and will automatically reload the Vault token from disk after receiving a `NOHUP` single from the local Nomad agent.

Stop and purge the `token-printer` Job:

```
nomad stop -purge token-printer
```
