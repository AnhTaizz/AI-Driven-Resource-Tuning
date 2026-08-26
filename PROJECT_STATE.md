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

- Benchmark strategy implementation status: **PLANNED / NOT_STARTED**
- Environment status: `LOCAL_YARN_V1` = **VERIFIED**
- Host: personal workstation with **16 GB physical RAM**; the approved infrastructure bundle observed an Intel Core i5-12450H with 8 physical cores / 12 logical processors.
- Logical topology: **two YARN NodeManagers on one physical host**.
- Purpose: a TPC-DS-based controlled Spark/YARN testbed that produces real Spark executions and real Spark History Server/YARN evidence from synthetic analytical inputs.
- Non-goal: production-cluster emulation or evidence that local configurations transfer directly to a company cluster.
- Benchmark foundation: TPC-DS/`dsdgen` -> immutable raw generated data -> controlled Parquet/Snappy materialization on HDFS -> project-defined TPC-DS-derived analytical workloads. This is not an official complete TPC-DS benchmark and implementation has not started.
- Verified advertised environment envelope: 2 vcores and 2048 MB of YARN memory per NodeManager, reduced conservatively from the earlier approximately 3 GB feasibility estimate; 4096 MB and 4 vcores in total. This verifies deployed scheduler capacity, not the safe/usable benchmark resource envelope.
- Human approval record: on 2026-08-25 the Human Tech Lead approved `LOCAL_YARN_V1` as **VERIFIED** for controlled local Spark-on-YARN research/bootstrap use, based on verification session `LOCAL_YARN_V1_20260824T073936243Z_7cb92321`, resolved snapshot `LOCAL_YARN_V1_SNAPSHOT_20260824T074804856Z_de925815`, and `docs/local_yarn_v1_human_review_packet.md`.
- Approved implementation target: Spark `3.5.9` no-Hadoop distribution, Hadoop `3.3.6`, Java 11 (Temurin `11.0.32+9`), and CPython `3.10.21`. All four versions were observed in the deployed runtime, including Python in `spark-client` and both NodeManager environments.
- Infrastructure implementation status: Docker/Compose configuration, Windows PowerShell 5.1-safe host invocation, bounded readiness checks, Java infrastructure smoke tooling, environment snapshot schemas, and machine-readable infrastructure-only evidence bundling are implemented. Static/PowerShell regression checks pass.
- Approved runtime verification session `LOCAL_YARN_V1_20260824T073936243Z_7cb92321` produced an internally `COMPLETE` infrastructure-only bundle and resolved snapshot `LOCAL_YARN_V1_SNAPSHOT_20260824T074804856Z_de925815`. Two DataNodes and two NodeManagers registered. Application `application_1787557265990_0001` finished `SUCCEEDED`, and the same ID was correlated across YARN, Spark History Server, and the HDFS event log. Host/Docker-VM `pswpin` and `pswpout` deltas were both zero; every observed running service cgroup reported swap current/peak/max `0`. Windows pagefile current usage rose from 3555 MB to 3768 MB while available host RAM fell from about 1721 MB to 1396 MB; this records capacity pressure but does not prove paging I/O, and no background-load threshold has been approved.
- Accepted verification limitations: both logical workers/DataNodes share one physical host; only the final session above is `COMPLETE`; earlier failed/swap-affected bundles remain immutable historical evidence; Docker VM memory was about 7.755 GiB while aggregate configured service limits can exceed it; post-smoke available host RAM was relatively low; pagefile growth was observed without continuous paging-I/O evidence; no continuous host/background-load threshold exists; and the smoke proves infrastructure plumbing, not sustained benchmark capacity or stability.

## Approved Research Framing

- Unit of observation: one Spark application execution.
- Primary recommendation approach: performance prediction + candidate search + multi-objective selection.
- Direct config regression: secondary comparison/baseline only.
- Primary required prediction target: runtime.
- Resource cost: derive from resource configuration × predicted runtime where possible.
- Reliability model: optional; use transparent rules if positive labels are sparse.
- Final success criterion: observed reduction in resource consumption with acceptable runtime/reliability trade-off versus meaningful baselines.

## Approved Phase 1 Decisions

- Historical dataset provenance for the MVP: **TPC-DS-based controlled benchmark executions**. These executions must remain explicitly labeled as benchmark/synthetic, non-official TPC data and must not be presented as company production workloads or official TPC Benchmark Results.
- Initial collector compatibility target: **Apache Spark 3.5.x with Hadoop/YARN 3.3.x**.
- The exact Spark and Hadoop/YARN patch versions must be captured from the benchmark runtime in source metadata, fixtures, and experiment records before version-specific parser behavior is frozen or the Data Gate is submitted for approval.
- Benchmark deployment mode: **Spark-on-YARN**. TPC-DS-derived benchmark provenance does not replace the collection sources: Phase 1 collects execution evidence from Spark History Server/event logs and YARN ResourceManager.
- Supported MVP recommendation mode: **static allocation**. Dynamic-allocation executions may be collected but are not recommendation candidates.
- Parallel SQL boundary: overlapping SQL executions/stages inside one Spark application. Multi-application workflow recommendation is outside the MVP.
- MVP feedback loop: explicit offline/manual collection, dataset rebuild/versioning, retraining, validation, and model promotion.
- MVP warnings: rule-based post-run diagnostics. Live running-job warnings are a stretch goal.
- Approved decisions: `docs/adr/ADR-0001-mvp-runtime-and-scope.md`, `docs/adr/ADR-0002-parallel-sql-boundary.md`, and `docs/adr/ADR-0004-adopt-tpc-ds-as-controlled-benchmark-foundation.md`.
- Local benchmark/bootstrap boundary: `docs/adr/ADR-0003-local-benchmark-environment-and-bootstrap.md`.
- ADR-0003 remains unchanged historical evidence. ADR-0004 supersedes only its old custom dataset/workload foundation and bootstrap identifiers.
- Initial dataset plan: `TPCDS_DEBUG` / `dataset_version = 1` for bootstrap and `TPCDS_SF1` / `dataset_version = 1` for later coverage.
- Initial workload plan: `W01_TPCDS_SCAN`, `W02_TPCDS_AGG`, `W03_TPCDS_JOIN`, `W04_TPCDS_MULTI_JOIN`, `W05_TPCDS_SHUFFLE_SORT`, and `W06_TPCDS_COMPLEX_SQL`, each with separate `workload_version = 1`.
- Planned bootstrap lineage: `EXP_001 -> LOCAL_YARN_V1 -> TPCDS_DEBUG -> W03_TPCDS_JOIN -> C1`; `C1` remains TBD and `EXP_001` is not authorized.

## Current Data Sources

Approved collection sources:

- Spark History Server REST API
- Spark event logs / listener-derived events where needed
- YARN ResourceManager REST API

Dataset provenance:

- TPC-DS-based controlled benchmark executions generated by this project; no dataset or workload has been generated/implemented under the new foundation yet.
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

## Verified Environment Evidence Notes

- Verified image evidence for session `LOCAL_YARN_V1_20260824T073936243Z_7cb92321` and snapshot `LOCAL_YARN_V1_SNAPSHOT_20260824T074804856Z_de925815` supports local `linux/amd64` image ID/repo digest `sha256:69d1b3114ff2a67e6196824999e53a3c1faf795622eac384b04987e014501d1b`.
- `UNVERIFIED_LEGACY`: the previously recorded digest `sha256:5902a010c834ec7a14c52dfd9b2fb0556b810d16dba9085859942d7713760a8e` has no supporting artifact in the reviewed repository evidence and is excluded from the `LOCAL_YARN_V1` verification basis.
- Temurin registry descriptor: `sha256:bde5229117ab6dbd31a267132258ecbcae228658a8d22981c365585e95588356`; selected `linux/amd64` child manifest: `sha256:b9b1c3fe34d01379bbed0e68e366b3b465e2131043823d236badbb9b9d288cee`.
- Environment decision: `LOCAL_YARN_V1` = **VERIFIED** by the Human Tech Lead on 2026-08-25 for the exact approved session/snapshot and scoped purpose above.

## Current Open Questions

- `C1`: **TBD**; Data Gate: **NOT_APPROVED**.
- Phase 1 contract consolidation: **AWAITING_HUMAN_TECH_LEAD_DECISION** in `docs/phase_1_contract_consolidation_review_packet.md`. The packet proposes options but does not approve or modify architecture, data contracts, feature availability, evaluation semantics, or recommendation policy.
- Repository durability: the accepted P01/P03 documentation is present in the current dirty worktree but is not yet represented by the current Git revision; the commit boundary and ownership of unrelated observability/workbook changes require Human confirmation.
- Evidence durability: the exact approved `LOCAL_YARN_V1` evidence remains local and Git-ignored. Durable retention and a clearly post-hoc integrity-manifest policy are **TBD**; missing capture-time provenance must not be reconstructed.
- Canonical application/attempt mapping and multi-attempt handling: **TBD / human approval required**. The approved unit remains one Spark application execution.
- Runtime-target eligibility for `FAILED`, `KILLED`, and other non-success outcomes: **TBD / human approval required**.
- Authoritative pre-run/as-of timestamp, global temporal cutoffs, Track B calendar-time isolation, and evaluation-block semantics: **TBD / human approval required**.
- Deterministic versioned `job_family_id` mapping: **TBD / human approval required**.
- Canonical metric namespace, source-resolution rules, and `execution_v1` versus `execution_v2` evolution: **TBD / human approval required**.
- Phase/component ownership for within-application concurrency and evidence-backed post-run diagnostics: **TBD / human approval required**.
- Exact `C1` bootstrap values for executor count, executor cores, executor memory, memory overhead, driver/ApplicationMaster overhead, and shuffle partitions: **TBD**. Environment verification is satisfied, but `C1` still requires a separate conservative configuration review and Human approval.
- Before systematic benchmark experiments, a separate Human-reviewed calibration step must validate usable dataset scale, usable resource envelope, host memory pressure, swap/paging behavior, repeat-run variability, and background-load/noise controls. This calibration is not performed or approved by P03.
- TPC-DS toolkit provenance/licensing/repository-hygiene disposition and integration option: **TBD / human review required before build**.
- Exact deterministic definition of `TPCDS_DEBUG`, raw generation scope/parameters, materialization schemas/partitioning/HDFS paths, and relationship checks: **TBD / human review required**.
- Exact SQL/action/correctness contracts for the six planned workload-version-1 definitions: **TBD**; `W03_TPCDS_JOIN` must be reviewed first for bootstrap readiness.
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
- Environment verification establishes identity and infrastructure plumbing only; sustained stability, usable benchmark scale/resource envelope, and paging/noise controls remain unvalidated until the future calibration gate.
- Docker VM memory and low host headroom can make otherwise scheduler-valid configurations unsafe under benchmark load.
- TPC-DS-derived Spark-on-YARN results may not transfer directly to a differently sized or configured production cluster.
- The selected-table/project-workload design is not an official complete TPC-DS benchmark and cannot support official TPC result comparisons.
- The committed toolkit has unresolved upstream-provenance, redistribution/licensing, repository-hygiene, and reproducible-build concerns.
- `TPCDS_DEBUG` is not yet defined; assuming fractional scale, arbitrary sampling, target bytes, or preserved relationships would threaten reproducibility and validity.
- The initial workload suite does not yet guarantee controlled skew coverage; any skew claim must be based on observed profiling/execution evidence.
- Local recommendations are environment-specific. Production/company deployment requires collection and retraining or explicit calibration using execution history from the target environment.
- SQL execution/stage concurrency metadata may be absent for some workloads or source versions.

## Next Milestone

```text
Immediate contract and repository-lineage prerequisite:
  Human review of docs/phase_1_contract_consolidation_review_packet.md
    -> select repository/evidence consolidation approach
    -> select or explicitly defer the unresolved Phase 1 semantics
    -> later authorization records approved choices in ADR/contracts

Completed prerequisite A:
  Human review of the COMPLETE LOCAL_YARN_V1 bundle and resolved snapshot
    -> LOCAL_YARN_V1 VERIFIED on 2026-08-25
    -> C1 remains a separate TBD decision

Remaining independent prerequisite B:
  Review toolkit provenance/licensing/integration
    -> approve reproducible build, TPCDS_DEBUG, materialization, and W03 contracts

B + collector/bootstrap readiness + separately approved C1
  -> human review of the exact EXP_001 specification
  -> only explicit later authorization may start EXP_001

Before systematic Phase 3 benchmark experiments:
  complete and obtain Human approval for the benchmark calibration gate
```

`application_1787557265990_0001` is infrastructure verification only. It is not `EXP_001`, benchmark evidence, ML data, or a canonical normalized execution. The future bootstrap mapping is `EXP_001 -> LOCAL_YARN_V1 -> TPCDS_DEBUG / 1 -> W03_TPCDS_JOIN / 1 -> C1`. P03 records environment approval only; it does not build the toolkit, generate/materialize data, implement workloads, resolve `C1`, approve the Data Gate, or authorize `EXP_001`.
