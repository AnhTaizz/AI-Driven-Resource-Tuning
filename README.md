# AI-Driven Resource Tuning

Research-oriented prototype for recommending Spark resource configurations from historical Spark/YARN executions while balancing runtime, resource efficiency, and reliability.

## Current Status

- Current phase: Phase 1 — Historical Data Collection
- Current gate: Data Gate — not yet approved
- Local benchmark environment: `LOCAL_YARN_V1` — `PLANNED`
- Bootstrap configuration `C1`: numeric resource values remain `TBD` until the environment is `VERIFIED`
- Next evidence target: `experiment_id = EXP_001` → `DATA_DEBUG_V1` → `W03_JOIN_V1` → `spark_application_id` → raw Spark History/YARN evidence → later `execution_id`

See `PROJECT_STATE.md` for approved decisions, open questions, risks, and the current milestone.

## Architecture Summary

The project uses a modular data/research pipeline:

```text
Synthetic data + versioned workloads + experiment specs
  -> local Spark-on-YARN benchmark executions
  -> Spark History/Event Logs + YARN ResourceManager
  -> immutable collection and normalization
  -> leakage-safe historical dataset and baselines
  -> runtime prediction and candidate search
  -> Pareto/constraint filtering and recommendation policy
  -> observed Spark validation
```

The local benchmark system generates controlled research evidence; it is not the production recommender and does not emulate a production cluster. Production/company use requires target-environment collection and retraining or explicit calibration.

## MVP Scope

- collect traceable Spark 3.5.x / Hadoop-YARN 3.3.x execution evidence, with exact patch versions verified from the runtime;
- preserve raw artifacts and source lineage;
- generate deterministic synthetic benchmark data and fixed Spark workloads;
- predict runtime for candidate static-allocation configurations;
- compare current/default, nearest-history, heuristic, and ML + optimization approaches under one evaluation protocol;
- return `NO_SAFE_RECOMMENDATION` outside supported coverage;
- validate final runtime/resource claims with observed Spark executions.

The MVP does not provide autonomous production tuning, scheduler modification, dynamic-allocation recommendations, or cross-environment transfer without target-environment evidence.

## Documentation

- `docs/project_requirements.md` — stable requirements and research boundary
- `docs/architecture.md` — components and data flow
- `docs/benchmark_environment.md` — planned/verified local Spark-on-YARN environment contract
- `docs/synthetic_data_spec.md` — deterministic input-domain and dataset lineage contract
- `docs/workload_catalog.md` — versioned Spark workload definitions
- `docs/benchmark_plan.md` — bootstrap and full benchmark experiment strategy
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
│   └── docker/           # scaffold only until deployment is implemented
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

A Docker/bootstrap quickstart will be added only after the infrastructure has run successfully and the commands have been verified.
