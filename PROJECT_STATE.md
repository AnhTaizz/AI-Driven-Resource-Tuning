# Current Project State

> This file is the single source of truth for current research/engineering state. Update it after an approved gate, architecture decision, dataset freeze, model freeze, or major blocker change.

## Project

- Name: AI-Driven Resource Tuning
- Goal: recommend Spark resource configurations from historical execution data while balancing runtime, resource efficiency, and reliability.
- Requirements baseline: `docs/project_requirements.md`
- Timebox: 8 weeks
- Current phase: **Phase 1 — Historical Data Collection**
- Current gate: **Data Gate — not yet approved**

## Local Benchmark Strategy

- Status: **PLANNED**
- Host: personal workstation with **16 GB physical RAM**; the complete infrastructure bundle observed an Intel Core i5-12450H with 8 physical cores / 12 logical processors, pending human environment review.
- Logical topology: **two YARN NodeManagers on one physical host**.
- Purpose: a controlled Spark/YARN experimental testbed that produces real Spark executions and real Spark History Server/YARN evidence from synthetic inputs.
- Non-goal: production-cluster emulation or evidence that local configurations transfer directly to a company cluster.
- Initial implementation envelope: **PLANNED** at 2 vcores and 2048 MB of YARN memory per NodeManager, reduced conservatively from the earlier approximately 3 GB feasibility estimate. The complete infrastructure bundle observed 4096 MB and 4 vcores in total; human approval is still required.
- Planned environment identity: `LOCAL_YARN_V1`; its evidence status changes to **VERIFIED** only after the exact runtime and capacity snapshot is observed and recorded in `docs/benchmark_environment.md`.
- Approved implementation target: Spark `3.5.9` no-Hadoop distribution, Hadoop `3.3.6`, Java 11 (Temurin `11.0.32+9`), and CPython `3.10.21`. All four versions were observed in the deployed runtime, including Python in `spark-client` and both NodeManager environments.
- Infrastructure implementation status: Docker/Compose configuration, Windows PowerShell 5.1-safe host invocation, bounded readiness checks, Java infrastructure smoke tooling, environment snapshot schemas, and machine-readable infrastructure-only evidence bundling are implemented. Static/PowerShell regression checks pass.
- Runtime verification session `LOCAL_YARN_V1_20260824T073936243Z_7cb92321` produced an internally `COMPLETE` infrastructure-only bundle and resolved snapshot `LOCAL_YARN_V1_SNAPSHOT_20260824T074804856Z_de925815`. Two DataNodes and two NodeManagers registered. Application `application_1787557265990_0001` finished `SUCCEEDED`, and the same ID was correlated across YARN, Spark History Server, and the HDFS event log. Host/Docker-VM `pswpin` and `pswpout` deltas were both zero; every observed running service cgroup reported swap current/peak/max `0`. Windows pagefile current usage rose from 3555 MB to 3768 MB while available host RAM fell from about 1721 MB to 1396 MB; this records capacity pressure but does not prove paging I/O, and no background-load threshold has been approved. `COMPLETE` does not self-approve the environment: `LOCAL_YARN_V1` remains **PLANNED** pending human review.

## Approved Research Framing

- Unit of observation: one Spark application execution.
- Primary recommendation approach: performance prediction + candidate search + multi-objective selection.
- Direct config regression: secondary comparison/baseline only.
- Primary required prediction target: runtime.
- Resource cost: derive from resource configuration × predicted runtime where possible.
- Reliability model: optional; use transparent rules if positive labels are sparse.
- Final success criterion: observed reduction in resource consumption with acceptable runtime/reliability trade-off versus meaningful baselines.

## Approved Phase 1 Decisions

- Historical dataset provenance for the MVP: **synthetic benchmark executions**. These executions must remain explicitly labeled as benchmark/synthetic data and must not be presented as company production workloads.
- Initial collector compatibility target: **Apache Spark 3.5.x with Hadoop/YARN 3.3.x**.
- The exact Spark and Hadoop/YARN patch versions must be captured from the benchmark runtime in source metadata, fixtures, and experiment records before version-specific parser behavior is frozen or the Data Gate is submitted for approval.
- Benchmark deployment mode: **Spark-on-YARN**. Synthetic benchmark provenance does not replace the collection sources: Phase 1 collects execution evidence from Spark History Server/event logs and YARN ResourceManager.
- Supported MVP recommendation mode: **static allocation**. Dynamic-allocation executions may be collected but are not recommendation candidates.
- Parallel SQL boundary: overlapping SQL executions/stages inside one Spark application. Multi-application workflow recommendation is outside the MVP.
- MVP feedback loop: explicit offline/manual collection, dataset rebuild/versioning, retraining, validation, and model promotion.
- MVP warnings: rule-based post-run diagnostics. Live running-job warnings are a stretch goal.
- Approved decisions: `docs/adr/ADR-0001-mvp-runtime-and-scope.md` and `docs/adr/ADR-0002-parallel-sql-boundary.md`.
- Local benchmark/bootstrap boundary: `docs/adr/ADR-0003-local-benchmark-environment-and-bootstrap.md`.

## Current Data Sources

Approved collection sources:

- Spark History Server REST API
- Spark event logs / listener-derived events where needed
- YARN ResourceManager REST API

Dataset provenance:

- Synthetic benchmark executions generated by this project.
- No production historical data is assumed for the MVP.

Version note:

- Implement against the approved Spark 3.5.x and Hadoop/YARN 3.3.x compatibility target.
- Record the exact runtime patch versions before freezing version-sensitive parser behavior, fixtures, or the Phase 1 data contract.
- Do not assume `latest` documentation matches the project runtime.

## Current Deliverables

Phase 1 must produce:

- working Spark History Server collector;
- working YARN ResourceManager collector;
- immutable raw payload storage;
- application ID correlation strategy;
- raw artifact manifest conforming to `docs/raw_data_contract.md`;
- raw data contract;
- missing-metric report;
- at least one traceable end-to-end execution sample;
- collector/parser tests.

## Current Open Questions

- Runtime versions were observed as Spark `3.5.9`, Hadoop `3.3.6`, Java `11.0.32+9`, and CPython `3.10.21`; human review is still required before environment verification approval.
- Final-session local OCI image descriptor/repo digest: `sha256:69d1b3114ff2a67e6196824999e53a3c1faf795622eac384b04987e014501d1b`; Docker-reported `linux/amd64` image manifest: `sha256:5902a010c834ec7a14c52dfd9b2fb0556b810d16dba9085859942d7713760a8e`.
- Temurin registry descriptor: `sha256:bde5229117ab6dbd31a267132258ecbcae228658a8d22981c365585e95588356`; selected `linux/amd64` child manifest: `sha256:b9b1c3fe34d01379bbed0e68e366b3b465e2131043823d236badbb9b9d288cee`.
- Active infrastructure decision: human review of the complete evidence bundle and resolved snapshot; the agent may not self-approve `LOCAL_YARN_V1`.
- `LOCAL_YARN_V1`: **PLANNED**; `C1`: **TBD**; Data Gate: **NOT_APPROVED**.
- Exact `C1` bootstrap values for executor count, executor cores, executor memory, memory overhead, driver/ApplicationMaster overhead, and shuffle partitions: **TBD until `LOCAL_YARN_V1` is VERIFIED**
- Authentication/security requirements for real cluster APIs: **TBD**
- Input data size source for all workload types: **TBD**
- Whether executor-level CPU/utilization is consistently available from chosen sources: **TBD**
- Runtime degradation guardrail for recommendation policy: **TBD / human approval required**

## Known Risks

- Event/API fields can vary across Spark/Hadoop versions.
- Some metrics may exist only after job completion and cannot be used as same-run model inputs.
- Benchmark dataset may be too small or too homogeneous.
- OOM/failure labels may be too rare for supervised reliability modeling.
- Repeated benchmark runs may be noisy due to shared-cluster contention, caching, JIT/warmup, and background load.
- Synthetic Spark-on-YARN results may not transfer directly to a differently sized or configured production cluster.
- Local recommendations are environment-specific. Production/company deployment requires collection and retraining or explicit calibration using execution history from the target environment.
- SQL execution/stage concurrency metadata may be absent for some workloads or source versions.

## Next Milestone

```text
Human review of the COMPLETE LOCAL_YARN_V1 bundle and resolved snapshot
  -> if approved, mark LOCAL_YARN_V1 VERIFIED
  -> only after VERIFIED approval resolve C1 and begin EXP_001
```

`application_1787557265990_0001` is infrastructure verification only. It is not `EXP_001`, benchmark evidence, ML data, or a canonical normalized execution. After the environment snapshot is **VERIFIED**, the human lead may resolve `C1` and authorize the Phase 1 bootstrap against `docs/raw_data_contract.md`. Do not proceed to `EXP_001`, data generation, collection, normalization, or feature engineering from this infrastructure task.
