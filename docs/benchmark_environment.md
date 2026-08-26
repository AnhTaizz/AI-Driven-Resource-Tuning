# Benchmark Environment — LOCAL_YARN_V1

## 1. Status and Purpose

- Environment ID: `LOCAL_YARN_V1`
- Current status: **VERIFIED**
- Human approval date: `2026-08-25`
- Approved verification session: `LOCAL_YARN_V1_20260824T073936243Z_7cb92321`
- Approved snapshot: `LOCAL_YARN_V1_SNAPSHOT_20260824T074804856Z_de925815`
- Bootstrap configuration: `C1` = **TBD**
- Research gate: Data Gate = **NOT_APPROVED**
- Physical host: personal workstation with 16 GB physical RAM
- Purpose: controlled local Spark-on-YARN research testbed
- Non-goal: production-cluster emulation

This environment will run controlled TPC-DS-derived inputs through real Spark jobs and expose real Spark History Server/event-log and YARN ResourceManager evidence. It is not an official complete TPC-DS environment. No exact version, image, host capacity, or service capacity in this document is considered verified until it is measured from the deployed environment.

The Human Tech Lead approved the exact session/snapshot above after reviewing
`local_yarn_v1_human_review_packet.md`. `VERIFIED` establishes the recorded
runtime identity, logical topology, advertised YARN capacity, HDFS health during
the snapshot, and Spark/YARN evidence plumbing. It does not establish a safe
benchmark envelope, sustained stability, production equivalence, or suitability
for every TPC-DS-derived scale/configuration.

## 2. Verified Logical Topology

All services run on one physical host. The two workers are logical isolation units, not two independent physical machines.

```text
Control services
  - HDFS NameNode
  - YARN ResourceManager
  - Spark History Server

Worker 1
  - HDFS DataNode
  - YARN NodeManager NM1

Worker 2
  - HDFS DataNode
  - YARN NodeManager NM2
```

## 3. Verified Runtime and Advertised YARN Envelope

The Human Tech Lead accepted these observations for the exact verified snapshot:

| Runtime component | Pinned implementation input | Evidence status |
|---|---|---|
| Spark | `3.5.9`, official `spark-3.5.9-bin-without-hadoop.tgz` | OBSERVED — HUMAN APPROVED |
| Hadoop/HDFS/YARN | `3.3.6` | OBSERVED — HUMAN APPROVED |
| Java | Temurin `11.0.32+9` / Java 11 | OBSERVED — HUMAN APPROVED |
| Python | CPython `3.10.21` | OBSERVED — HUMAN APPROVED |

The Docker build verifies the official Spark/Hadoop checksums and the Python
source checksum. The resolved workstation evidence records the Temurin
`linux/amd64` child manifest `sha256:b9b1c3fe34d01379bbed0e68e366b3b465e2131043823d236badbb9b9d288cee`
and final-session local OCI descriptor `sha256:69d1b3114ff2a67e6196824999e53a3c1faf795622eac384b04987e014501d1b`.

| Component | Advertised capacity | Evidence status |
|---|---:|---|
| NodeManager `NM1` | 2 vcores / 2048 MB YARN memory | OBSERVED — HUMAN APPROVED |
| NodeManager `NM2` | 2 vcores / 2048 MB YARN memory | OBSERVED — HUMAN APPROVED |

These conservative observed values replace the earlier approximately 3 GB-per-NodeManager feasibility estimate. They verify deployed scheduler capacity only. Container allocation, ApplicationMaster/driver/executor overhead, OS/Docker and HDFS/Spark service memory, usable host memory, and a safe resource envelope must still be validated through controlled bootstrap/calibration work before benchmark configuration bounds are approved.

## 4. Verified Snapshot Contract and Approval Basis

The approved snapshot records the required environment identity and evidence:

- host CPU model and logical/physical core counts;
- physical RAM and measured available RAM before services start;
- host OS and architecture;
- container/runtime engine and version;
- exact Spark version;
- exact Hadoop/YARN version;
- exact Java version;
- exact Python version;
- image names plus immutable digests or distribution/build identifiers;
- HDFS/YARN/Spark History Server service configuration versions;
- YARN scheduler/queue and minimum/maximum allocation settings;
- each NodeManager's advertised vcores and memory;
- total effective YARN vcores and memory;
- Spark event-log and History Server locations/configuration;
- time zone/clock assumptions;
- mechanism used to observe swap and background host load.

Store environment-specific endpoints and secrets outside committed documentation. A sanitized resolved snapshot may be committed under a future versioned environment config.

The snapshot contract deliberately separates `planned_config` from
`observed_runtime_evidence`. A runtime verification session has its own
machine-readable status (`INCOMPLETE`, `FAILED`, or `COMPLETE`), and `COMPLETE`
means only that the infrastructure evidence bundle is internally complete. It
does not self-approve the environment. Human approval is a later external state
transition recorded in this document, `PROJECT_STATE.md`, and the review packet.
Host evidence is captured in three phases:
`HOST_BASELINE` before services start, `CLUSTER_IDLE` before smoke submission,
and `POST_SMOKE` after the infrastructure smoke completes.

## 5. Approved Infrastructure Verification Bundle

Session `LOCAL_YARN_V1_20260824T073936243Z_7cb92321` verified the
configured service topology and submitted infrastructure-only application
`application_1787557265990_0001`. The retained evidence does not prove executor
placement across both NodeManagers, so no stronger placement claim is made.

Observed component results:

- exact runtime versions: Spark `3.5.9`, Hadoop `3.3.6`, Java `11.0.32+9`, and CPython `3.10.21`;
- two live DataNodes, with zero under-replicated, corrupt, or missing blocks;
- Spark YARN archive `hdfs:///spark/jars/spark-3.5.9-jars.zip`, containing 194 root-level JAR entries;
- two RUNNING NodeManagers, each advertising 2048 MB and 2 vcores;
- total YARN capacity of 4096 MB and 4 vcores;
- CapacityScheduler with minimum allocation 256 MB / 1 vcore and maximum allocation 2048 MB / 2 vcores;
- smoke application `FINISHED/SUCCEEDED` with empty YARN diagnostics;
- a matching completed Spark History Server record reporting Spark `3.5.9`;
- application-ID correlation passed.

The machine-readable verification bundle is internally `COMPLETE`. Docker Linux VM `pswpin` and `pswpout` deltas were both zero, and every observed running `LOCAL_YARN_V1` service cgroup reported current/peak/max swap of zero. Windows pagefile current usage rose from 3555 MB to 3768 MB while available host RAM fell from about 1721 MB to 1396 MB; this is capacity context, not proof of paging I/O, and no background-load threshold is invented from it.

The immutable resolved snapshot retains `PLANNED_PENDING_HUMAN_REVIEW` because
that was its capture-time status before the Human decision. On 2026-08-25 the
Human Tech Lead approved `LOCAL_YARN_V1` as **VERIFIED** for this exact session
and snapshot. The source bundle/snapshot remains unchanged, and the approval
does not approve a Research Gate or benchmark capacity.

## 6. Verification Checklist

- [x] HDFS health check passes and a test artifact can be written/read.
- [x] Both logical DataNodes and NodeManagers register as intended.
- [x] YARN reports measured scheduler and NodeManager capacities.
- [x] Spark submits in YARN mode with static allocation.
- [x] Spark event logs are persisted.
- [x] Spark History Server displays the completed application.
- [x] YARN ResourceManager exposes the same application ID/attempt evidence.
- [x] Host swap and background-load observations can be recorded.
- [x] Exact versions and immutable image/distribution identifiers are captured.
- [x] The Human Tech Lead reviewed the resolved snapshot and approved the environment as `VERIFIED` on 2026-08-25.

## 7. Validity and Limitations

- Both logical workers and both DataNodes share one physical host, storage domain, Docker/WSL VM, and failure domain.
- Only verification session `LOCAL_YARN_V1_20260824T073936243Z_7cb92321` is currently `COMPLETE`.
- Previous failed verification attempts, including swap-affected sessions, remain immutable historical evidence and must not be deleted or relabeled.
- Docker VM memory was approximately 7.755 GiB while aggregate configured service memory limits can exceed that value.
- Available host RAM was relatively low after the smoke run: about 1396 MiB.
- Windows pagefile use grew during the observed interval, but continuous Windows paging-I/O evidence was not collected; absence of future paging is not established.
- No continuous host/background-load threshold or noise-acceptance rule has yet been approved.
- The infrastructure smoke proves runtime/evidence plumbing only, not sustained benchmark capacity or stability.
- Host swap during a benchmark invalidates that run pending investigation.
- Excessive background load must be flagged; important comparisons should be rerun.
- Two logical NodeManagers/containers on one host share CPU, RAM, memory bandwidth, disk, network, and host noise. They are not equivalent to independent physical enterprise workers.
- Verification does not establish safe operation at every scheduler-valid resource configuration, large TPC-DS workload capacity, physical multi-node fault isolation, or final benchmark scale suitability.
- Local configurations and recommendations are specific to `LOCAL_YARN_V1`.
- Production/company use requires collecting target-environment execution history and retraining or explicitly calibrating the model/policy for that environment.
- Company history must retain its own environment IDs and provenance; it must not be relabeled as local benchmark data.

## 8. Future Benchmark Calibration Gate

Before systematic benchmark experiments, a separate controlled calibration step
must produce observed evidence and receive Human Tech Lead review for at least:

- usable dataset scale;
- usable resource envelope;
- host memory pressure;
- swap/paging behavior;
- repeat-run variability;
- background-load/noise controls.

This later gate is not satisfied by environment verification. It is not a
prerequisite for separately reviewed TPC-DS integration or bootstrap preparation,
and P03 does not perform or approve the calibration.

## 9. Change Control

After an environment becomes **VERIFIED**, any material change to capacity, Spark/Hadoop patch version, image digest, scheduler boundary, or service topology creates a new environment snapshot. A material compatibility or capacity change should receive a new `benchmark_environment_id` rather than silently mutating verified evidence.
