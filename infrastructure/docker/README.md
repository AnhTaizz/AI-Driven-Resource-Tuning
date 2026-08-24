# LOCAL_YARN_V1 infrastructure

This directory contains the **PLANNED** single-host Spark-on-YARN environment.
It is infrastructure verification tooling, not benchmark evidence, `EXP_001`, or
ML data. Running these commands does not authorize changing `LOCAL_YARN_V1` to
`VERIFIED`; the observed snapshot and smoke evidence require human review.

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
artifacts. Neither a `COMPLETE` infrastructure bundle nor a snapshot changes the
environment from `PLANNED`; human review is still required.
