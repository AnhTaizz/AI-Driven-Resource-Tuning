# LOCAL_YARN_V1 infrastructure

This directory contains the implementation and verification tooling for the
single-host Spark-on-YARN environment. The Human Tech Lead approved
`LOCAL_YARN_V1` as **VERIFIED** only for session
`LOCAL_YARN_V1_20260824T073936243Z_7cb92321` and snapshot
`LOCAL_YARN_V1_SNAPSHOT_20260824T074804856Z_de925815`. This tooling is not
benchmark evidence, `EXP_001`, or ML data, and running it cannot self-approve a
new or materially changed environment snapshot.

## Pinned runtime

- Apache Spark 3.5.9, official no-Hadoop distribution
- Apache Hadoop 3.3.6
- Eclipse Temurin Java 11.0.32+9
- CPython 3.10.21

Spark and Hadoop archives are checked with SHA-512 during the image build.
Python source is checked with SHA-256. `start.ps1` pulls the exact Temurin tag,
resolves an immutable registry digest, and passes that reference to both
Dockerfile stages. Runtime evidence separately records the actual image ID,
architecture, source tag, resolved base reference, and each service container's
image identity. Some local image stores expose a content-addressed repository
digest after build and others do not; the evidence records it when present and
does not infer that the image was pushed to a registry.

## Commands on Windows

```powershell
Copy-Item `
  configs/environments/local_yarn_v1.env.example `
  configs/environments/local_yarn_v1.env

powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File tests/infrastructure/test_local_yarn_v1_contract.ps1 `
  -EnvFile configs/environments/local_yarn_v1.env

powershell.exe -NoProfile -ExecutionPolicy Bypass -File infrastructure/docker/host/start.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File infrastructure/docker/host/verify.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File infrastructure/docker/host/stop.ps1
```

`stop.ps1` preserves all named HDFS volumes. There is intentionally no reset
script. `docker compose down --volumes` destroys the NameNode namespace,
DataNode blocks, Spark event logs, and aggregated YARN logs.

Development UIs are exposed only on loopback:

- NameNode: <http://localhost:9870>
- ResourceManager: <http://localhost:8088>
- Spark History Server: <http://localhost:18080>

## Run the observability test job

`LocalYarnObservability` is a small Java Spark job for learning and checking the
monitoring surfaces. It creates deterministic in-memory rows, cache/storage
blocks, SQL and shuffle stages, then keeps two bounded tasks active so there is
time to inspect the live UI. It is classified
`INFRASTRUCTURE_OBSERVABILITY_ONLY`: it is not `EXP_001`, `C1`, benchmark
evidence, a synthetic dataset generator, collector output, or ML data.

The source is mounted read-only into an ephemeral `spark-client` and compiled in
`/tmp` with the pinned Java/Spark runtime. It is deliberately not baked into the
Docker image, so running it does not change the image digest cited by the formal
environment snapshot.

Run it **after** `start.ps1` and `verify.ps1`, but before `stop.ps1`. The launcher
rejects an `INCOMPLETE` or `FAILED` formal verification session and requires the
current image/container identities to match that session's final evidence. This
prevents the extra application from contaminating the smoke bundle's
idle-cluster assumption or being attributed to a stale verified runtime.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File infrastructure/docker/host/run-observability-test.ps1 `
  -ObservationSeconds 180
```

Valid observation windows are 30 through 600 seconds. Keep terminal A open.
Once the live monitoring surfaces are ready, the launcher prints the observed
YARN application ID and exact live URLs. It then waits for completion, resolves
the completed History Server attempt ID, and checks the live Spark REST API,
worker-executor Prometheus samples, final YARN status, and completed History
Server REST records. A `PASS` marker is printed only after all of those checks
actually succeed.

### Terminal B: inspect the running application

Copy the printed ID into `$appId`. These defaults follow the example environment
file; substitute its overridden ports if you changed them.

```powershell
$rm = 'http://127.0.0.1:8088'
$appId = 'application_REPLACE_ME'

# YARN application record and attempts.
(Invoke-RestMethod "$rm/ws/v1/cluster/apps/$appId").app |
  Select-Object id,state,finalStatus,progress,allocatedMB,allocatedVCores,runningContainers
Invoke-RestMethod "$rm/ws/v1/cluster/apps/$appId/appattempts" |
  ConvertTo-Json -Depth 20
$yarnAttempts = Invoke-RestMethod "$rm/ws/v1/cluster/apps/$appId/appattempts"
$appAttemptId = @($yarnAttempts.appAttempts.appAttempt)[0].appAttemptId
Invoke-RestMethod "$rm/ws/v1/cluster/apps/$appId/appattempts/$appAttemptId/containers" |
  ConvertTo-Json -Depth 20

# Confirm that the live Spark API exposes this running application.
$liveApplication = @(
  Invoke-RestMethod "$rm/proxy/$appId/api/v1/applications"
) | Where-Object id -eq $appId | Select-Object -First 1
$liveSparkKey = $appId

# Executor aggregates and stage/task metric summaries.
Invoke-RestMethod "$rm/proxy/$appId/api/v1/applications/$liveSparkKey/executors" |
  ConvertTo-Json -Depth 30
Invoke-RestMethod "$rm/proxy/$appId/api/v1/applications/$liveSparkKey/stages?withSummaries=true" |
  ConvertTo-Json -Depth 30

# Prometheus text emitted by the live executor-metrics endpoint.
(Invoke-WebRequest `
  "$rm/proxy/$appId/metrics/executors/prometheus" `
  -UseBasicParsing).Content
```

Open the printed live Spark UI URL, normally
`http://127.0.0.1:8088/proxy/<application_id>/`. Useful tabs are **Jobs**,
**Stages**, **Storage**, **Executors**, **SQL**, and **Environment**. Do not use
`localhost:4040`: in YARN cluster mode the driver is inside an ApplicationMaster
container and this repository exposes its UI through the ResourceManager proxy.
The test also sets `spark.ui.killEnabled=false`, so its UI is observational.

Other useful read-only YARN endpoints are:

```text
GET /ws/v1/cluster/metrics
GET /ws/v1/cluster/nodes
GET /ws/v1/cluster/scheduler
GET /ws/v1/cluster/apps/<application_id>
GET /ws/v1/cluster/apps/<application_id>/appattempts
GET /ws/v1/cluster/apps/<application_id>/appattempts/<full_app_attempt_id>/containers
```

For the containers route, use the full `appAttemptId` returned by the attempts
payload (for example `appattempt_..._000001`), not its numeric `id`. Query it
while the application is live; this ResourceManager may return an empty object
after the completed containers have been removed from its in-memory state.

### After completion: inspect Spark History Server

The live Spark 3.5.9 payload observed in this YARN deployment does not include an
`attemptId` while the application is running, so the live REST key is the base
YARN application ID. The completed History Server record does include an
attempt ID; do not invent it before it is observed.

The History Server scans HDFS event logs every 5 seconds in this environment.
The launcher waits for a completed record, but when checking manually allow one
refresh interval. Use the attempt-aware key `<application_id>/<attempt_id>` for
YARN cluster mode:

```powershell
$history = 'http://127.0.0.1:18080'
$historyApplication = Invoke-RestMethod "$history/api/v1/applications/$appId"
$attemptId = @(
  $historyApplication.attempts | Where-Object completed -eq $true
)[0].attemptId
$sparkKey = "$appId/$attemptId"

Invoke-RestMethod "$history/api/v1/applications/$sparkKey/jobs" |
  ConvertTo-Json -Depth 30
Invoke-RestMethod "$history/api/v1/applications/$sparkKey/stages?withSummaries=true" |
  ConvertTo-Json -Depth 30
Invoke-RestMethod "$history/api/v1/applications/$sparkKey/allexecutors" |
  ConvertTo-Json -Depth 30
Invoke-RestMethod "$history/api/v1/applications/$sparkKey/sql" |
  ConvertTo-Json -Depth 30
Invoke-RestMethod "$history/api/v1/applications/$sparkKey/environment" |
  ConvertTo-Json -Depth 30
```

Use `executors` for active executors while the application is running and
`allexecutors` for active plus removed executors in history. Spark documents
task `executorRunTime` in milliseconds but `executorCpuTime` in nanoseconds;
do not divide them without unit conversion and a validated aggregation rule.
Executor `memoryUsed` is Spark storage memory, not process RSS or YARN container
allocation. `peakExecutionMemory` covers Spark execution structures used by
shuffle/aggregation operators, not JVM heap or RSS. YARN `memorySeconds` and
`vcoreSeconds` are time-integrated allocations, while completed applications
may report current-allocation fields as `-1`. Zero spill or GC is a valid result
for this small job, and absent fields must remain missing rather than being
replaced with zero.

The bounded sleeping tasks intentionally make elapsed time and CPU time diverge;
therefore no runtime, utilization, capacity, or resource-saving conclusion may
be drawn from this job. The API responses viewed here are not immutable Phase 1
collector artifacts and do not satisfy the Data Gate.

Versioned primary references:

- [Spark 3.5.9 monitoring and REST API](https://spark.apache.org/docs/3.5.9/monitoring.html)
- [Spark 3.5.9 on YARN](https://spark.apache.org/docs/3.5.9/running-on-yarn.html)
- [Hadoop 3.3.6 ResourceManager REST API](https://hadoop.apache.org/docs/r3.3.6/hadoop-yarn/hadoop-yarn-site/ResourceManagerRest.html)

`start.ps1` first checks the selected env file, Docker access, and whether this
Compose project is already running. It must be run while the LOCAL_YARN_V1
services are stopped so `HOST_BASELINE` is genuinely pre-start. A Docker-access
failure still creates a non-active `FAILED` bundle; a successful stopped-cluster
preflight activates a new session before capturing the baseline. Any later
failure is also marked `FAILED`, while a started but not-yet-verified cluster
remains `INCOMPLETE`.

Evidence is written under
`artifacts/infrastructure_smoke/<verification_id>/`, with status in
`verification_status.json`. The observed environment snapshot is written under
`artifacts/environment_snapshots/LOCAL_YARN_V1/<snapshot_id>/`. The snapshot
separates planned configuration from observed runtime evidence and cites the
same-session HDFS, YARN, Spark History, image, version, and three-phase host
artifacts. Neither a `COMPLETE` infrastructure bundle nor a snapshot changes an
environment status automatically. The 2026-08-25 Human decision separately
verified the exact session/snapshot named above; any material runtime, capacity,
scheduler, or topology change requires new evidence and Human review.
