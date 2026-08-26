# LOCAL_YARN_V1 — Human Tech Lead Review Packet

## 1. Decision boundary

This packet was prepared for the Human Tech Lead decision on the exact resolved
`LOCAL_YARN_V1` infrastructure snapshot. On 2026-08-25 the Human Tech Lead
approved that environment as `VERIFIED` for its limited purpose as a controlled
local Spark-on-YARN research/bootstrap testbed.

The evidence review did not self-approve the environment; the explicit Human
decision is recorded in Section 7. That decision does not authorize or resolve
`C1`, the Data Gate, TPC-DS generation/materialization, `EXP_001`, or any
benchmark, ML, performance, capacity, savings, or production-transfer claim.

| Identity | Value |
|---|---|
| Verification ID | `LOCAL_YARN_V1_20260824T073936243Z_7cb92321` |
| Snapshot ID | `LOCAL_YARN_V1_SNAPSHOT_20260824T074804856Z_de925815` |
| Evidence classification | `INFRASTRUCTURE_VERIFICATION_ONLY` |
| Infrastructure smoke application | `application_1787557265990_0001` |
| Bundle status | `COMPLETE` |
| Snapshot status at capture | `PLANNED_PENDING_HUMAN_REVIEW` |
| Human decision/current environment status | `APPROVED` / `VERIFIED` |
| `C1` / Data Gate | `TBD` / `NOT_APPROVED` |

Primary review sources:

- [resolved snapshot](../artifacts/environment_snapshots/LOCAL_YARN_V1/LOCAL_YARN_V1_SNAPSHOT_20260824T074804856Z_de925815/snapshot.json)
- [complete evidence bundle](../artifacts/infrastructure_smoke/LOCAL_YARN_V1_20260824T073936243Z_7cb92321/)
- [benchmark environment](benchmark_environment.md)
- [current project state](../PROJECT_STATE.md)
- [ADR-0003](adr/ADR-0003-local-benchmark-environment-and-bootstrap.md)

## 2. Executive finding

The final bundle is internally consistent for the pinned runtime, logical
topology, effective YARN capacity and scheduler, HDFS health, Spark History
Server/event-log path, successful Spark-on-YARN submission, and application-ID
correlation. It is sufficient for the Human Tech Lead to make an infrastructure
identity/plumbing decision.

It does not demonstrate representative benchmark capacity or stability. The
Human approval accepts, but does not remove, low host headroom, Docker memory-limit overcommit,
inconclusive Windows pagefile observations, significant background load, two
earlier smoke sessions invalidated by Linux VM swap activity, and the fact that
only one session reached `COMPLETE`.

## 3. Verification matrix

| Review item | Observed evidence | Finding |
|---|---|---|
| Spark version | Spark `3.5.9` from the client/NodeManager runtime evidence and completed History attempt | Supported |
| Hadoop version | Hadoop `3.3.6` from the client and both NodeManager environments | Supported |
| Java / Python | Temurin `11.0.32+9`; CPython `3.10.21` on `spark-client`, `nodemanager-1`, and `nodemanager-2` | Supported |
| DataNodes | Two live DataNodes, `datanode-1` and `datanode-2` | Supported; both are logical workers on one host |
| NodeManagers | Two `RUNNING` NodeManagers, each advertising 2048 MiB and 2 vcores | Supported |
| Total YARN capacity | 4096 MiB and 4 vcores | Supported as advertised scheduler capacity, not guaranteed safe benchmark headroom |
| Scheduler / calculator | CapacityScheduler; `DominantResourceCalculator`; default queue at 100%; min 256 MiB/1 vcore; max 2048 MiB/2 vcores | Supported |
| HDFS health | Two live DataNodes; under-replicated, corrupt, and missing block counts all zero; write/read verification emitted `HDFS_VERIFICATION=PASS` | Supported for the observed interval; no independent physical storage/failure domain |
| Spark History Server | Completed attempt `1` for the exact application ID, Spark `3.5.9` | Supported |
| Event logging | Enabled at `hdfs:///spark-history`; matching `application_1787557265990_0001_1.zstd` listed in HDFS | Supported for existence and History ingestion; event-log bytes/hash are not retained in the packet |
| YARN execution | Spark application `FINISHED/SUCCEEDED`, progress 100%, diagnostics empty | Supported for the infrastructure smoke only |
| Application correlation | Exact ID matches the submit output, YARN record, History record, Spark environment, event-log filename, status, and snapshot reference; `CORRELATION_VERIFICATION=PASS` | Supported |
| Docker/container identity | Docker Desktop `4.74.0`, Engine/client `29.4.3`, Compose `5.1.3`, Linux `amd64`; all observed services use image ID/repo digest `sha256:69d1b3114ff2a67e6196824999e53a3c1faf795622eac384b04987e014501d1b` | Supported, subject to the digest traceability note below |
| Swap/pagefile | Final interval: Linux VM `pswpin`/`pswpout` deltas zero and observed running service cgroup swap zero; Windows pagefile current use increased | Partially supported: no new Linux paging observed, but Windows paging I/O was not measured |
| Local limitations | Single 16 GB host, shared CPU/RAM/disk/network/failure domain, environment-specific results | Explicitly documented and confirmed by host evidence |

Primary artifact mapping:

- Versions: [`runtime_versions_by_environment.json`](../artifacts/infrastructure_smoke/LOCAL_YARN_V1_20260824T073936243Z_7cb92321/runtime_versions_by_environment.json)
- HDFS: [`hdfs_report.stdout.txt`](../artifacts/infrastructure_smoke/LOCAL_YARN_V1_20260824T073936243Z_7cb92321/hdfs_report.stdout.txt)
- YARN nodes/capacity: [`yarn_node_resources.json`](../artifacts/infrastructure_smoke/LOCAL_YARN_V1_20260824T073936243Z_7cb92321/yarn_node_resources.json)
- Scheduler: [`yarn_effective_config.json`](../artifacts/infrastructure_smoke/LOCAL_YARN_V1_20260824T073936243Z_7cb92321/yarn_effective_config.json)
- YARN application: [`yarn_application.json`](../artifacts/infrastructure_smoke/LOCAL_YARN_V1_20260824T073936243Z_7cb92321/yarn_application.json)
- History Server: [`history_application.json`](../artifacts/infrastructure_smoke/LOCAL_YARN_V1_20260824T073936243Z_7cb92321/history_application.json)
- Event log: [`spark_event_log_listing.stdout.txt`](../artifacts/infrastructure_smoke/LOCAL_YARN_V1_20260824T073936243Z_7cb92321/spark_event_log_listing.stdout.txt)
- Effective Spark properties: [`spark_effective_config.json`](../artifacts/infrastructure_smoke/LOCAL_YARN_V1_20260824T073936243Z_7cb92321/spark_effective_config.json)
- Correlation output: [`spark_submit_output.stdout.txt`](../artifacts/infrastructure_smoke/LOCAL_YARN_V1_20260824T073936243Z_7cb92321/spark_submit_output.stdout.txt)
- Images/runtime: [`service_images_final.json`](../artifacts/infrastructure_smoke/LOCAL_YARN_V1_20260824T073936243Z_7cb92321/service_images_final.json) and [`docker_info.stdout.txt`](../artifacts/infrastructure_smoke/LOCAL_YARN_V1_20260824T073936243Z_7cb92321/docker_info.stdout.txt)
- Host/swap: [`host_baseline.json`](../artifacts/infrastructure_smoke/LOCAL_YARN_V1_20260824T073936243Z_7cb92321/host_baseline.json), [`cluster_idle.json`](../artifacts/infrastructure_smoke/LOCAL_YARN_V1_20260824T073936243Z_7cb92321/cluster_idle.json), [`post_smoke.json`](../artifacts/infrastructure_smoke/LOCAL_YARN_V1_20260824T073936243Z_7cb92321/post_smoke.json), and [`swap_assessment.json`](../artifacts/infrastructure_smoke/LOCAL_YARN_V1_20260824T073936243Z_7cb92321/swap_assessment.json)

## 4. Missing or qualified evidence

1. **Representative capacity and repeatability:** only one short infrastructure
   smoke reached `COMPLETE`. It is not a TPC-DS-derived workload, a sustained
   load test, `EXP_001`, or proof that the full advertised YARN envelope is safe.
2. **Run-quality rule:** host observations are point-in-time snapshots. No
   approved background-load/minimum-free-memory threshold or continuous
   CPU/memory/disk/network trace exists.
3. **Windows paging:** pagefile occupancy is recorded, but Windows page-in/page-out
   I/O is not. The evidence neither proves Windows paging nor proves its absence.
4. **Immutable lineage:** the bundle has no bundle-wide checksum manifest or
   repository code revision. It retains an HDFS event-log listing, not the raw
   event-log bytes/hash. YARN reports `logAggregationStatus = NOT_START`, so
   aggregated AM/executor logs are absent.
5. **Execution placement:** two NodeManagers were registered and running, but no
   retained executor/container placement artifact proves that the smoke exercised
   both workers.
6. **Clock validation:** UTC timestamps and runtime timezone `+07` are coherent,
   but no explicit clock synchronization or drift check is retained.
7. **Image-manifest traceability:** at P02 review time, `PROJECT_STATE.md` named
   a Docker-reported `linux/amd64` manifest
   `sha256:5902a010c834ec7a14c52dfd9b2fb0556b810d16dba9085859942d7713760a8e`,
   but that value does not appear in the reviewed bundle or resolved snapshot.
   P03 records it only as `UNVERIFIED_LEGACY` and excludes it from the
   verification basis. Approved image evidence directly supports
   `sha256:69d1b3114ff2a67e6196824999e53a3c1faf795622eac384b04987e014501d1b`;
   no digest was reconstructed or invented.

## 5. Contradictions and reconciliations

No unreconciled contradiction was found in the final versions, topology, YARN
capacity, scheduler, HDFS, Spark/YARN success, or application-ID chain.

- Bundle `COMPLETE` and snapshot status `PLANNED_PENDING_HUMAN_REVIEW` describe
  capture-time evidence states. The later Human decision establishes current
  environment status `VERIFIED` without mutating those source artifacts.
- ADR-0003's approximately 3 GiB-per-NodeManager value was a feasibility
  estimate. The current observed plan is 2048 MiB per NodeManager, explicitly
  documented as a conservative replacement.
- ADR-0003's old dataset/workload IDs are retained historical evidence and were
  superseded by ADR-0004; they are not part of this environment decision.
- HDFS reports about 1.97 TiB by summing two logical DataNode volumes, but both
  use the same physical host/storage domain. It is not independent physical
  capacity or fault-tolerance evidence.
- Eleven earlier sessions remain recorded as `FAILED`; they do not override the
  final session, but they are negative evidence. In particular,
  `LOCAL_YARN_V1_20260824T044901826Z_266ce0af` observed `pswpin +2` and
  `pswpout +525`, while `LOCAL_YARN_V1_20260824T053225874Z_6586164a` observed
  `pswpout +74`. Both were correctly invalidated.

## 6. Capacity and benchmark-validity risks

- Host available RAM fell from about 2752 MiB before start to 1721 MiB at
  cluster idle and 1396 MiB post-smoke. Windows pagefile current use rose from
  3386 MiB to 3555 MiB to 3768 MiB.
- Point-in-time host CPU load was 40% before start, 60% at cluster idle, and 46%
  post-smoke, with substantial unrelated processes present.
- Docker reported 7.755 GiB of VM memory. The steady service memory limits total
  8.125 GiB; including the ephemeral `spark-client` submission limit gives
  8.75 GiB. Limits are maxima rather than reservations, but this overcommit and
  the low host headroom are material OOM/noise risks.
- YARN is a narrow 4096 MiB/4-vcore envelope with a 2048 MiB/2-vcore maximum
  allocation. A future `C1` must separately account for the ApplicationMaster,
  driver, executors, and overhead; no `C1` value is implied here.
- Both logical workers share physical CPU, memory bandwidth, storage, network,
  Docker/WSL, and failure domains. HDFS replication is logical, not hardware
  isolation.
- The smoke emitted a native-Hadoop-library fallback warning. This is a fixed
  local-runtime characteristic to preserve in later comparisons, not evidence
  of production equivalence.
- Future timings remain vulnerable to background load, caching, JIT/warmup, and
  shared-host contention and require controlled repeats and run-quality rules.
- Results are specific to `LOCAL_YARN_V1`; they cannot be presented as official
  TPC-DS results, production-cluster evidence, or directly transferable resource
  recommendations.

## 7. Human Tech Lead decision

The Human Tech Lead selected exactly one decision on 2026-08-25:

- [x] **APPROVE** `LOCAL_YARN_V1` as `VERIFIED` for the exact snapshot and
  infrastructure-only purpose above, accepting the recorded limitations.
- [ ] **DEFER** pending specifically named evidence or conditions.
- [ ] **REJECT / REVISE** the current environment envelope or topology. A
  material capacity/topology/runtime change requires a new snapshot and may
  require a new environment ID.

The approval establishes the recorded runtime versions, two-DataNode/two-
NodeManager topology, advertised YARN capacity, HDFS health for the snapshot,
Spark-on-YARN submission, History Server/EventLog/YARN evidence availability,
and application-ID correlation. It accepts the limitations in Sections 4–6 for
controlled integration/bootstrap work.

It does not establish sustained benchmark stability, large-workload capacity,
safe operation for every scheduler-valid configuration, absence of future host
paging, production equivalence, physical multi-node isolation, or final scale
suitability. Those properties require the separately reviewed calibration gate.
Approval still does not resolve `C1`, approve the Data Gate, or authorize
`EXP_001`.

```text
Decision: APPROVED -> LOCAL_YARN_V1 VERIFIED
Reviewer: Human Tech Lead/Researcher
Date: 2026-08-25
Accepted limitations / required conditions: Sections 4-6 and the scoped decision above
Required follow-up evidence: benchmark calibration before systematic experiments
```
