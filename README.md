# AI-Driven Resource Tuning

Research-oriented prototype for recommending Spark resource configurations from historical Spark/YARN executions while balancing runtime, resource efficiency, and reliability.

## Current Status

- Current phase: Phase 1 — Historical Data Collection
- Current gate: Data Gate — not yet approved
- Local benchmark environment: `LOCAL_YARN_V1` — `VERIFIED` for the exact Human-approved session/snapshot recorded in `docs/benchmark_environment.md`
- Verified infrastructure runtime: Spark `3.5.9`, Hadoop `3.3.6`, Java `11.0.32+9`, CPython `3.10.21`; verification establishes controlled local infrastructure/evidence plumbing, not benchmark capacity
- Benchmark foundation: ADR-0004 adopts a TPC-DS-based controlled benchmark; toolkit/data/materialization/workload implementation has not started
- Bootstrap configuration `C1`: numeric resource values remain `TBD` pending a separate explicit review against the verified environment
- Remaining independent decisions: toolkit/provenance/build, dataset, materialization, W03 contract/implementation, `C1`, and exact bootstrap gates from `docs/tpcds_implementation_plan.md`
- `EXP_001`: not authorized; only an exact later B1 review after both prerequisite tracks and collector readiness may authorize submission

See `PROJECT_STATE.md` for approved decisions, open questions, risks, and the current milestone.

## Architecture Summary

The project uses a modular data/research pipeline:

```text
TPC-DS -> dsdgen -> immutable raw generated data
  -> controlled Parquet/Snappy materialization on HDFS
  -> versioned TPC-DS-derived workloads + experiment specs
  -> local Spark-on-YARN benchmark executions
  -> Spark History/Event Logs + YARN ResourceManager
  -> immutable collection and normalization
  -> leakage-safe historical dataset and baselines
  -> runtime prediction and candidate search
  -> Pareto/constraint filtering and recommendation policy
  -> observed Spark validation
```

The local system is a **TPC-DS-based controlled benchmark**, not an official complete TPC-DS benchmark. Its project-defined analytical workloads do not produce official TPC-DS results and are not comparable to official TPC Benchmark Results. The local benchmark generates controlled research evidence; it is not the production recommender and does not emulate a production cluster. Production/company use requires target-environment collection and retraining or explicit calibration.

## MVP Scope

- collect traceable Spark 3.5.x / Hadoop-YARN 3.3.x execution evidence, with exact patch versions verified from the runtime;
- preserve raw artifacts and source lineage;
- generate deterministic TPC-DS-derived benchmark inputs, materialize selected tables, and run fixed project workloads;
- predict runtime for candidate static-allocation configurations;
- compare current/default, nearest-history, heuristic, and ML + optimization approaches under one evaluation protocol;
- return `NO_SAFE_RECOMMENDATION` outside supported coverage;
- validate final runtime/resource claims with observed Spark executions.

The MVP does not provide autonomous production tuning, scheduler modification, dynamic-allocation recommendations, or cross-environment transfer without target-environment evidence.

## Documentation

- `docs/project_requirements.md` — stable requirements and research boundary
- `docs/architecture.md` — components and data flow
- `docs/benchmark_environment.md` — planned/verified local Spark-on-YARN environment contract
- `docs/benchmark_data_spec.md` — TPC-DS generation/materialization and dataset-lineage contract
- `docs/workload_catalog.md` — versioned Spark workload definitions
- `docs/benchmark_plan.md` — bootstrap and full benchmark experiment strategy
- `docs/tpcds_implementation_plan.md` — gated future implementation sequence and toolkit audit
- `docs/raw_data_contract.md` / `docs/data_schema.md` / `docs/feature_schema.md` — data and leakage contracts
- `docs/evaluation_protocol.md` / `docs/recommendation_policy.md` — evaluation and selection policy
- `docs/README.md` — complete documentation index

## Repository Structure

```text
.
├── README.md
├── AGENTS.md
├── PROJECT_STATE.md
├── configs/
│   ├── environments/
│   ├── datasets/
│   ├── workloads/
│   └── experiments/
├── docs/                 # requirements, contracts, phases, ADRs
├── infrastructure/
│   └── docker/           # LOCAL_YARN_V1 implementation and verification tooling
├── src/
│   ├── benchmark/
│   │   ├── generation/
│   │   ├── workloads/
│   │   └── runner/
│   ├── collection/
│   ├── normalization/
│   ├── features/
│   ├── datasets/
│   ├── baselines/
│   ├── modeling/
│   ├── optimization/
│   └── recommendation/
└── tests/
```

The Docker/bootstrap commands are documented in `infrastructure/docker/README.md`.
The container build and Java infrastructure smoke executed successfully, including
YARN/History/event-log correlation for `application_1787557265990_0001`, a no-swap
host/runtime interval, and a resolved environment snapshot. The Human Tech Lead
approved that exact evidence as `LOCAL_YARN_V1 = VERIFIED`; `C1` remains `TBD`,
the Data Gate remains `NOT_APPROVED`, and benchmark capacity/stability still
requires controlled calibration before systematic experiments.
