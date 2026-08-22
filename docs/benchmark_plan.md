# Benchmark and Data Generation Plan

## 1. Objective

Generate a dataset with enough **workload diversity** and **resource-configuration diversity** to learn and evaluate resource trade-offs. The goal is not to maximize run count; it is to maximize useful coverage under the available compute budget.

This plan has two distinct execution levels:

1. **Bootstrap benchmark**: one to five executions used only to establish the environment-to-collector trace and produce `EXP_001`.
2. **Full benchmark**: systematic Phase 3 executions used to build coverage for dataset, baseline, and ML work.

The bootstrap does not satisfy the Dataset Gate and must not be used to claim recommendation quality or resource savings.

## 2. Bootstrap Benchmark

### 2.1 Purpose and Expected Trace

The first target is:

```text
LOCAL_YARN_V1
  -> DATA_DEBUG_V1
  -> W03_JOIN_V1
  -> Spark-on-YARN application
  -> Spark application ID
  -> Spark History Server/Event Log + YARN ResourceManager evidence
  -> immutable raw artifacts
  -> EXP_001
```

### 2.2 Bootstrap Dataset

- Dataset ID: `DATA_DEBUG_V1`
- Target materialized size: approximately 100–300 MB
- Distribution: `NORMAL`
- Actual row counts, HDFS byte size, partition count, generator version, and seed must be recorded after materialization.

The target size is a planning range, not the model input. Downstream records use measured `actual_input_size_bytes` (normalized to `input_size_bytes` where the source contract permits).

### 2.3 Bootstrap Workload and Configuration

- Workload: `W03_JOIN_V1`, defined in `workload_catalog.md`.
- Configuration ID: `C1`.
- Executors: 1.
- Executor cores: 1.
- Executor memory: 1 GiB.
- Dynamic allocation: disabled.
- Adaptive Query Execution (AQE): disabled.
- `spark.sql.shuffle.partitions`: explicitly set and held fixed for all repeats of this experiment.

Executor memory overhead, driver memory, shuffle partition count, and queue settings must be resolved against the deployed YARN minimum-allocation and capacity limits before submission. If `C1` is invalid in the verified environment, record the incompatibility and approve the smallest valid replacement rather than silently changing the experiment.

## 3. Full Benchmark Specification

### 3.1 Dataset Scales and Distributions

Initial planning ranges:

| Scale label | Target materialized size | Role |
|---|---:|---|
| `DEBUG` | 100–300 MB | pipeline/bootstrap debugging |
| `SMALL` | about 500 MB | low-load region |
| `MEDIUM` | about 1–2 GB | central local operating region |
| `LARGE` | initially about 3–5 GB | upper local feasibility region |

Each scale should be generated with `NORMAL` and, where applicable, `SKEWED` distributions. Scale names are labels only; all experiments record actual materialized byte size and row counts. `LARGE` must be reduced or omitted if the verified 16 GB host cannot execute it without swap or invalid host pressure.

### 3.2 Workload Catalog

The initial fixed workload versions are:

- `W01_FILTER_V1`
- `W02_AGGREGATION_V1`
- `W03_JOIN_V1`
- `W04_SHUFFLE_HEAVY_V1`
- `W05_SKEW_JOIN_V1`

Their exact tables, transformations, materialization actions, and controlled settings are defined in `workload_catalog.md`. Workload code and input dataset version remain fixed while resource configurations are compared.

### 3.3 Resource Regions

Primary dimensions:

- number of executors;
- cores per executor;
- executor memory.

Secondary dimensions are changed only when required:

- driver memory;
- executor memory overhead.

For each workload/scale, first locate representative **under-provisioned**, **reasonable**, and **over-provisioned** regions. Sample within those regions; do not run the full Cartesian product unless the measured compute budget justifies it.

## 4. Workload Families

Minimum target coverage where practical:

1. ETL/filter/projection
2. aggregation/group-by
3. join-heavy
4. shuffle-heavy
5. skewed join/aggregation
6. small, medium, and large input scales relative to the test environment

These families map to the versioned workloads in `workload_catalog.md`; the catalog is authoritative for executable behavior.

## 5. Experiment Design Principles

Use a staged design:

### Stage A — Feasibility Envelope

Find configurations that are clearly:

- under-provisioned;
- reasonable;
- over-provisioned.

This establishes valid ranges and prevents wasting runs on obviously impossible configurations.

### Stage B — Coverage Matrix

Sample combinations across workload families, input scales, and resource regions.

### Stage C — Local Refinement

Add runs near promising trade-offs or poorly modeled regions based on data coverage, not based on final test outcomes.

## 6. Replication and Noise Control

Spark measurements can be noisy. When practical:

- repeat important configurations at least twice;
- use three repeats for final benchmark comparisons if budget allows;
- randomize/interleave configuration order rather than running all “small” configs then all “large” configs;
- record cluster load/environment state where available;
- avoid comparing cached and uncached runs as if equivalent;
- document whether input/output data is cached or materialized;
- consider a warm-up run for workloads affected by JVM/JIT/startup effects, but never silently discard runs—mark warm-up explicitly.
- keep AQE disabled for initial controlled experiments; a later AQE-enabled series requires a distinct experiment specification and may not be mixed silently;
- keep dynamic allocation disabled for all MVP recommendation candidates;
- keep `spark.sql.shuffle.partitions` fixed within an experiment and record its resolved value;
- detect host swap before/during/after a run where the host permits it; any detected swap makes the benchmark invalid pending investigation;
- flag excessive background load and do not treat an affected run as directly comparable without anomaly review.

## 7. Experiment Metadata

Every run must record:

- experiment ID;
- `benchmark_environment_id` resolving exact Spark/Hadoop/Java/Python/deployment image metadata;
- workload family/version;
- workload ID and version;
- input dataset ID/version, generator version, seed, row counts, partition count, and actual materialized size;
- experiment repeat index;
- exact Spark config;
- AQE state and configured shuffle partition count;
- Spark/Hadoop versions;
- cluster/local environment information;
- start/end time;
- code revision;
- raw contract/collector versions;
- raw data references;
- observed status/runtime/resource outcomes;
- anomaly notes.

## 8. Run Validity and Anomaly Rules

- **Host swap detected**: mark the run `INVALID_PENDING_INVESTIGATION`; do not use it in comparable benchmark/model data until reviewed.
- **Excessive background load**: add a quality flag and anomaly note; rerun important comparisons when possible.
- **Configuration rejected by YARN**: record as a feasibility result, not an observed workload runtime.
- **Collection incomplete**: preserve the execution and raw evidence, but exclude it from modeling fields that cannot be traced.
- **Failed/OOM execution**: preserve it as observed evidence; never relabel or synthesize the outcome.
- Define concrete host-load thresholds only after the environment exposes reliable counters; do not invent thresholds before measurement.

## 9. Data Coverage Report

At Dataset Gate, report:

- total successful/failed runs;
- runs per workload family;
- runs per input scale;
- distribution of executors/cores/memory;
- count of unique configurations;
- sparse regions of the feature/config space;
- frequency of spill/OOM/failure positives;
- repeated-run variance;
- known benchmark limitations.

## 10. Safety

When using a shared/company cluster:

- do not intentionally create disruptive OOM/stress experiments without explicit permission;
- respect queue/resource limits;
- schedule heavy runs in approved windows;
- use synthetic/local benchmarks for destructive edge cases when needed;
- never submit unbounded candidate grids to a shared cluster.

On the personal workstation, stop or reduce a workload before host stability is threatened. The local testbed is controlled research infrastructure, not a stress-test target.

## 11. Gate

Dataset generation passes when the dataset is sufficiently varied for the planned model/evaluation and its limitations are quantified. A large but homogeneous dataset does not pass merely because of row count.
