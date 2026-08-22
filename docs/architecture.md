# Architecture

## 1. Objective

Build a research-grade system that collects historical Spark/YARN execution data, creates reproducible workload/configuration features, predicts candidate runtime, evaluates resource trade-offs, and recommends a valid Spark configuration for a future run.

The design intentionally favors a modular monolith/data pipeline over microservices for the 8-week prototype. Components should have clean interfaces so they can later be deployed independently if justified.

## 2. System Context

```text
                  LOCAL BENCHMARK SYSTEM
                           |
             +-------------+-------------+
             |                           |
  Synthetic Dataset Generator      Experiment Specs
             |                           |
             v                           v
            HDFS                  Experiment Runner
             |                           |
             +-------------+-------------+
                           v
                    Spark Workloads
                           |
                           v
                 Local Spark-on-YARN
                           |
             +-------------+-------------+
             |                           |
             v                           v
 Spark History Server / Event Logs   YARN ResourceManager
             |                           |
             +-------------+-------------+
                           v
                    Collection Layer
                    │
                    ▼
             Immutable Raw Zone
                    │
                    ▼
        Normalization + Data Contracts
                    │
                    ▼
          Feature Extraction Pipeline
                    │
                    ▼
             Historical Dataset
                    │
        ┌───────────┴───────────┐
        ▼                       ▼
     Baselines            Performance Model
                                │
                                ▼
                     Candidate Config Generator
                                │
                                ▼
                    Runtime / Risk Prediction
                                │
                                ▼
                       Derived Resource Cost
                                │
                                ▼
                         Pareto / Constraints
                                │
                                ▼
                      Recommendation Policy
                                │
                                ▼
                     Explanation + Demo/API
                                │
                                ▼
                       Real Spark Validation
```

The local benchmark system is a **data-generation subsystem** for research evidence. It is not part of the production recommendation path. Future authorized company executions enter through the same collection/data-contract boundary; they do not need to use the local synthetic generator or experiment runner.

## 3. Component Boundaries

### 3.1 Benchmark Data-Generation Subsystem

Responsibilities:

- materialize deterministic synthetic datasets in HDFS from versioned generator specifications;
- execute versioned Spark workloads from explicit experiment specifications;
- submit controlled static-allocation configurations to the local Spark-on-YARN environment;
- record experiment, dataset, workload, environment, seed, configuration, and repeat lineage;
- produce real Spark application IDs for collection and later systematic benchmarking.

Non-responsibilities:

- fabricating Spark/YARN metrics or outcomes;
- emulating a production cluster;
- collecting or normalizing source evidence;
- making model or recommendation decisions.

The bootstrap path creates the first one to five executions needed to prove the Phase 1 collector path. Phase 3 later uses the same subsystem for systematic dataset generation. See `benchmark_environment.md`, `synthetic_data_spec.md`, `workload_catalog.md`, and `adr/ADR-0003-local-benchmark-environment-and-bootstrap.md`.

### 3.2 Collection Layer

Responsibilities:

- call Spark History Server and YARN ResourceManager APIs;
- ingest event logs where required;
- capture request/source metadata;
- persist raw source payloads without destructive transformation;
- retry transient failures with bounded backoff;
- record collection status and errors.

Every captured response, event-log object, or collection failure must satisfy `raw_data_contract.md`. Collection does not rename source fields, convert units, or infer missing values.

Non-responsibilities:

- feature engineering;
- model logic;
- recommendation decisions.

### 3.3 Raw Zone

Raw data is immutable and append-only at the experiment/research level.

Recommended layout:

```text
data/raw/
  spark_history/<collection_date>/<application_id>/...
  yarn_rm/<collection_date>/<application_id>/...
  eventlog/<application_id>/...
```

A re-run of normalization should not require recollecting source data.

Each payload has an immutable sidecar manifest containing source operation, sanitized request context, collection status, exact environment/source versions, collector version, byte size, and SHA-256 integrity evidence. Retries append new artifacts rather than overwrite prior evidence.

### 3.4 Normalization Layer

Converts source-specific payloads into typed canonical records while preserving source lineage.

Each normalized field should retain:

- source system;
- source path/field where practical;
- collection timestamp;
- parser/schema version;
- missing reason where relevant.

The normalized topology includes application/config records and child stage, SQL execution, executor, and YARN attempt/container records where supported. SQL/stage interval overlap is preserved for concurrency analysis, while application/executor/YARN allocation remains the resource-accounting boundary.

### 3.5 Feature Pipeline

Produces one modeling record per execution, plus historical-context features built only from information available before the target execution.

Feature code must be deterministic and tested independently from model code.

Every modeling record has an `as_of_timestamp`. Pre-run and historical-context features must be reproducible using only evidence available strictly before that timestamp.

### 3.6 Baseline Layer

Implements current/default, nearest-history, and simple heuristic recommendations using the same candidate constraints and evaluation protocol as ML where possible.

### 3.7 Model Layer

MVP target:

```text
(workload features, historical context, candidate config)
    -> predicted runtime
```

A separate reliability model is optional and only justified if labels support it.

### 3.8 Candidate + Optimization Layer

Candidate generator enforces hard validity constraints first. Prediction happens only for valid candidates.

Optimization then compares predicted runtime, derived resource cost, and reliability risk. Pareto filtering may be used, followed by a human-approved recommendation policy.

### 3.9 Serving/Demo Layer

The demo may be CLI or Streamlit/FastAPI-backed UI. It must show data provenance and clearly label observed vs predicted values.

The demo is not a production control plane and must not automatically alter live cluster settings unless separately approved.

## 4. Non-Goals for the MVP

- changing Spark scheduler internals;
- online reinforcement learning;
- autonomous production cluster reconfiguration;
- complex microservice topology;
- Kubernetes migration;
- exhaustive auto-tuning of every Spark parameter;
- deep learning without evidence of need.
- dynamic-allocation configuration recommendation;
- multi-application workflow resource recommendation;
- live running-job warning;
- automated retraining/model promotion.

## 5. Data Flow Guarantees

1. Raw source payload is preserved.
2. Normalized records are reproducible from raw data + parser version.
3. Feature records are reproducible from normalized data + feature version.
4. Model artifact is reproducible from dataset version + config + code revision + seed.
5. Recommendation is reproducible from model version + feature record + candidate policy version.
6. Validation result is traceable to exact Spark config and experiment ID.
7. Raw artifact integrity is verifiable from its manifest and SHA-256 checksum.
8. Concurrent SQL/stage durations are not summed as application wall-clock time or independent resource allocations.

## 6. Version Compatibility

Spark History Server behavior is reconstructed from persisted event logs, and available API/events vary by Spark version. YARN ResourceManager REST resources also depend on Hadoop/YARN version. Therefore:

- pin actual runtime versions in environment metadata;
- test collectors against those versions;
- use version-specific fixtures/golden samples;
- avoid coding to undocumented fields seen only in one sample.

The approved MVP compatibility family is Spark 3.5.x with Hadoop/YARN 3.3.x on Spark-on-YARN. Exact patch, Java/Python, distribution/image, and relevant service configuration versions are pinned by `benchmark_environment_id` before version-sensitive parser behavior is implemented or frozen. See `adr/ADR-0001-mvp-runtime-and-scope.md`.

## 7. MVP Operational Boundaries

- Synthetic benchmark workloads are executed on Spark-on-YARN and remain explicitly labeled as non-production evidence.
- Static allocation is the supported recommendation mode.
- The feedback loop is explicit offline collection, dataset rebuild/versioning, retraining, validation, and model promotion.
- Waste/shortage warnings are post-run diagnostics; live warnings are outside the MVP.
- Parallel SQL means overlapping SQL executions/stages within one Spark application, as defined by `adr/ADR-0002-parallel-sql-boundary.md`.
- `LOCAL_YARN_V1` is a single-host, two-NodeManager controlled testbed. Its planned resource envelope is not frozen until verified against the deployed runtime.
- Local recommendations are environment-specific; transfer to a company/production environment requires target-environment collection and retraining or explicit calibration.

## 8. Failure Handling

Collectors:

- bounded retry for transient HTTP/network failures;
- fail explicitly on authentication/authorization errors;
- never replace missing data with guessed values;
- persist collection errors with application ID and source.

Feature/model pipeline:

- reject schema-incompatible inputs;
- surface missing required features;
- allow optional metrics to remain null with documented handling.

Recommendation layer:

- return `NO_SAFE_RECOMMENDATION` when inputs, model coverage, or candidate constraints are insufficient;
- fall back to a baseline only if the fallback policy is explicit.

## 9. Official References

- Apache Spark Monitoring and Instrumentation: https://spark.apache.org/docs/latest/monitoring.html
- Apache Spark Web UI / History Server: https://spark.apache.org/docs/latest/web-ui.html
- Apache Spark Security: https://spark.apache.org/docs/latest/security.html
- Hadoop YARN ResourceManager REST API: https://hadoop.apache.org/docs/stable/hadoop-yarn/hadoop-yarn-site/ResourceManagerRest.html
