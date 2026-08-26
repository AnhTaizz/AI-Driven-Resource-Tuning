# Benchmark and Data Generation Plan

## 1. Objective and Claim Boundary

Generate enough **workload diversity** and **resource-configuration diversity** to learn and evaluate Spark resource trade-offs under the available compute budget. The goal is useful, reproducible coverage rather than maximum run count.

This is a **TPC-DS-based controlled benchmark** using project-defined **TPC-DS-derived analytical workloads**. It is not an official complete TPC-DS benchmark, does not calculate official TPC-DS metrics, and does not produce results comparable to official TPC Benchmark Results.

The plan has two execution levels:

1. **Bootstrap benchmark**: one to five executions used only to establish the environment-to-collector trace and produce `EXP_001`.
2. **Full benchmark**: systematic Phase 3 executions used to build coverage for dataset, baseline, and ML work.

The bootstrap does not satisfy the Dataset Gate and must not be used to claim recommendation quality or resource savings.

## 2. Bootstrap Benchmark

### 2.1 Purpose and Expected Trace

The planned first trace is:

```text
experiment_id = EXP_001
  -> benchmark_environment_id = LOCAL_YARN_V1
  -> dataset_id = TPCDS_DEBUG
  -> dataset_version = 1
  -> workload_id = W03_TPCDS_JOIN
  -> workload_version = 1
  -> spark-submit with resolved C1
  -> spark_application_id = application_...
  -> immutable Spark History/Event Log + YARN ResourceManager evidence
  -> later normalization
  -> execution_id = EXEC_...
```

`EXP_001` is assigned before submission and remains the experiment ID. It does not replace the source-observed `spark_application_id` or the canonical normalized `execution_id`.

Neither P01 nor P03 authorizes any step in that trace. The implementation/review prerequisites are defined in `tpcds_implementation_plan.md`.

### 2.2 Bootstrap Dataset

- `dataset_id`: `TPCDS_DEBUG`
- `dataset_version`: `1`
- Status: **PLANNED**
- Exact deterministic generation/subsetting method: **TBD / human approval required**
- Target and actual materialized size: **not asserted**

`TPCDS_DEBUG` must be generated/materialized under `benchmark_data_spec.md`. Actual rows, raw/HDFS bytes, files, partitions, generator/build identity, and relationship-check results are recorded only after they are observed. No old custom-generator `NORMAL`/`SKEWED` or 100–300 MB assumption carries into this dataset.

### 2.3 Bootstrap Workload and Configuration

- `workload_id`: `W03_TPCDS_JOIN`
- `workload_version`: `1`
- Planned relationship path: `store_sales JOIN item JOIN date_dim`
- Planned grouping dimensions: `d_year` and `i_category`
- Configuration ID: `C1`
- Configuration status: **TBD**; `LOCAL_YARN_V1` verification is complete, but a separate explicit `C1` review against the approved snapshot is still required
- Dynamic allocation: disabled
- AQE: disabled
- `spark.sql.shuffle.partitions`: **TBD**, then fixed for comparable repeats

Before implementation, the workload review must freeze exact join type, filters, aggregates, null handling, action/output, correctness reconciliation, and broadcast-threshold behavior.

Required properties of `C1` remain:

- static allocation;
- valid under verified YARN scheduler/container/NodeManager limits;
- conservative enough to leave capacity for the ApplicationMaster/driver and local services;
- sufficient to complete the reviewed W03 contract on `TPCDS_DEBUG` without host swap.

| Field | Current unresolved value |
|---|---|
| `num_executors` | TBD |
| `executor_cores` | TBD |
| `executor_memory` | TBD |
| `executor_memory_overhead` | TBD |
| `driver_memory` / ApplicationMaster overhead | TBD |
| `spark.sql.shuffle.partitions` | TBD |

Resolve all values against the reviewed environment snapshot. Record the effective configuration in the future `EXP_001` record; never backfill this planning document as if those values had been known earlier.

## 3. Full Benchmark Specification

### 3.1 Initial Dataset Coverage

| `dataset_id` | `dataset_version` | Planned role | Status |
|---|---:|---|---|
| `TPCDS_DEBUG` | `1` | bootstrap and pipeline debugging | Definition TBD |
| `TPCDS_SF1` | `1` | initial scale-factor-1 selected-table coverage | Not generated/measured |

`TPCDS_SF1` refers to this project's selected-table materialization from reviewed scale-factor-1 generator output; it does not imply a complete official TPC-DS database/run.

Dataset labels never substitute for observed input size. Each experiment records the exact table/path inputs and derives `actual_input_size_bytes` only from the materialized inputs genuinely known before submission.

The requirement to evaluate multiple workload/input regions remains. If these two initial identities do not provide enough scale diversity, quantify the gap and propose separately versioned additional datasets for Human Tech Lead approval. Do not silently create SMALL/MEDIUM/LARGE aliases or extrapolate sizes.

### 3.2 Initial Workload Catalog

Each workload has separate `workload_version = 1`:

- `W01_TPCDS_SCAN`;
- `W02_TPCDS_AGG`;
- `W03_TPCDS_JOIN`;
- `W04_TPCDS_MULTI_JOIN`;
- `W05_TPCDS_SHUFFLE_SORT`;
- `W06_TPCDS_COMPLEX_SQL`.

The exact executable contracts live in `workload_catalog.md` and must pass their future review gates. Workload logic and dataset version remain fixed while resource configurations are compared.

The initial suite does not claim a designed skew case. Profile observed key/task distributions; if skew coverage is insufficient, report the gap and request a separately reviewed dataset/workload change.

### 3.3 Resource Regions

Primary dimensions:

- number of executors;
- cores per executor;
- executor memory.

Secondary dimensions change only when required:

- driver memory;
- executor memory overhead.

For each workload/dataset, first locate representative **under-provisioned**, **reasonable**, and **over-provisioned** regions. Sample within those regions; do not run a full Cartesian product unless measured compute budget and research value justify it.

## 4. Workload-Family Coverage

Initial planned families:

1. scan/filter/projection;
2. aggregation;
3. join plus aggregation;
4. multi-dimension join;
5. shuffle and sort;
6. complex SQL;
7. multiple input/resource regions relative to the verified environment;
8. skew/task-imbalance coverage only when supported by observed profiling.

The catalog is authoritative for executable behavior. A workload name is not evidence that Spark actually shuffled, spilled, skewed, failed, or used a particular physical join strategy.

## 5. Experiment Design Principles

Use a staged design:

### Stage A — Benchmark Calibration / Feasibility Envelope

This is a separate, controlled calibration step before the systematic Stage B/C
experiment matrix. Environment verification alone does not satisfy it. Using
bounded, reviewed calibration executions, validate at minimum:

- usable dataset scale;
- usable resource envelope;
- host memory pressure;
- swap/paging behavior;
- repeat-run variability;
- background-load/noise controls.

Record observed results, rejected/invalid runs, and proposed thresholds or
envelopes for Human Tech Lead review. Find configurations that are clearly
under-provisioned, reasonable, and over-provisioned without intentionally
destabilizing the host. Stage B/C systematic experiments may begin only after
the calibration evidence and controls are accepted.

### Stage B — Coverage Matrix

Sample combinations across workload families, dataset identities, and resource regions.

### Stage C — Local Refinement

Add runs near promising trade-offs or poorly modeled regions based on training/coverage evidence, never final test outcomes.

## 6. Replication and Noise Control

When practical:

- repeat important configurations at least twice;
- use three repeats for final benchmark comparisons if budget allows;
- randomize/interleave configuration order;
- record environment/background-load observations;
- avoid treating cached and uncached runs as equivalent;
- document all input/output cache and materialization behavior;
- mark warm-up runs explicitly and never silently discard them;
- keep AQE disabled for the initial controlled series;
- keep dynamic allocation disabled for MVP recommendation candidates;
- keep `spark.sql.shuffle.partitions` fixed within an experiment and record it;
- detect host swap before/during/after runs where available; detected swap makes a run invalid pending investigation;
- flag excessive background load and review affected comparisons.

## 7. Experiment Metadata

Every run records:

- experiment ID;
- `benchmark_environment_id` and environment snapshot reference;
- workload family, `workload_id`, and separate `workload_version`;
- `dataset_id`, separate `dataset_version`, and dataset manifest reference;
- toolkit/generator build and raw-generation lineage through the dataset manifest;
- materialization-spec version, exact selected table/path inputs, measured rows/files/partitions, and actual materialized size through the dataset manifest;
- repeat index;
- exact Spark configuration;
- AQE/dynamic-allocation state and configured shuffle partitions;
- start/end time and code revision;
- raw contract/collector versions and raw evidence references;
- observed status/runtime/resource outcomes;
- host-swap/background-load flags and anomaly notes.

Static environment attributes resolve through the environment snapshot. Source-observed versions required for collection provenance remain governed by `raw_data_contract.md`.

## 8. Run Validity and Anomaly Rules

- **Host swap detected:** mark `INVALID_PENDING_INVESTIGATION`; exclude from comparable/model data pending review.
- **Excessive background load:** add a quality flag/anomaly note and rerun important comparisons where possible.
- **Configuration rejected by YARN:** record as feasibility evidence, not observed workload runtime.
- **Collection incomplete:** preserve execution/evidence but exclude untraceable modeling fields.
- **Failed/OOM execution:** preserve as observed evidence; never relabel or synthesize it.
- **Workload correctness failure:** preserve the execution but exclude it from valid performance comparison.
- **Dataset/manifest mismatch:** stop the run path; never infer or repair identity silently.
- Define host-load thresholds only from reliable observed counters and human-approved rules.

## 9. Data Coverage Report

At Dataset Gate, report:

- successful/failed/invalid runs;
- runs per workload family and dataset version;
- observed materialized input-size distribution;
- distribution of executors/cores/memory and unique configurations;
- sparse/uncovered feature/configuration regions;
- frequency of observed spill/OOM/failure positives;
- repeated-run variance;
- key/task-imbalance evidence and the absence of designed skew coverage where applicable;
- benchmark/toolkit/materialization limitations.

## 10. Safety

On shared/company infrastructure, do not run disruptive stress/OOM cases without explicit permission, exceed queue limits, or submit unbounded candidate grids.

On the personal workstation, stop or reduce a workload before host stability is threatened. The local environment is controlled research infrastructure, not a stress-test target.

## 11. Preconditions and Gates

Before any toolkit/data/workload implementation, follow the independent T1–T3, D1/D2, M1/M2, W1–W4, and B1 gates in `tpcds_implementation_plan.md`. They do not replace Research Gates.

Systematic Phase 3 execution begins only after the Phase 1 collection path works, the Data Gate is human-approved, and the Stage A benchmark-calibration evidence has been separately reviewed and accepted. Dataset generation passes only when workload/resource/input coverage is sufficient for the planned model/evaluation and limitations are quantified. A large but homogeneous dataset does not pass by row count alone.
