# Benchmark and Data Generation Plan

## 1. Objective

Generate a dataset with enough **workload diversity** and **resource-configuration diversity** to learn and evaluate resource trade-offs. The goal is not to maximize run count; it is to maximize useful coverage under the available compute budget.

## 2. Workload Families

Minimum target coverage where practical:

1. ETL/filter/projection
2. aggregation/group-by
3. join-heavy
4. shuffle-heavy
5. skewed join/aggregation
6. small, medium, and large input scales relative to the test environment

Keep workload code and input data fixed while comparing resource configurations.

## 3. Resource Dimensions

Primary dimensions:

- number of executors;
- cores per executor;
- executor memory.

Secondary dimensions only if required:

- driver memory;
- executor memory overhead.

Do not explode the experiment into a full Cartesian product unless the compute budget clearly supports it.

## 4. Experiment Design Principles

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

## 5. Replication and Noise Control

Spark measurements can be noisy. When practical:

- repeat important configurations at least twice;
- use three repeats for final benchmark comparisons if budget allows;
- randomize/interleave configuration order rather than running all “small” configs then all “large” configs;
- record cluster load/environment state where available;
- avoid comparing cached and uncached runs as if equivalent;
- document whether input/output data is cached or materialized;
- consider a warm-up run for workloads affected by JVM/JIT/startup effects, but never silently discard runs—mark warm-up explicitly.

## 6. Experiment Metadata

Every run must record:

- experiment ID;
- `benchmark_environment_id` resolving exact Spark/Hadoop/Java/Python/deployment image metadata;
- workload family/version;
- input dataset version and size;
- exact Spark config;
- Spark/Hadoop versions;
- cluster/local environment information;
- start/end time;
- code revision;
- raw contract/collector versions;
- raw data references;
- observed status/runtime/resource outcomes;
- anomaly notes.

## 7. Data Coverage Report

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

## 8. Safety

When using a shared/company cluster:

- do not intentionally create disruptive OOM/stress experiments without explicit permission;
- respect queue/resource limits;
- schedule heavy runs in approved windows;
- use synthetic/local benchmarks for destructive edge cases when needed;
- never submit unbounded candidate grids to a shared cluster.

## 9. Gate

Dataset generation passes when the dataset is sufficiently varied for the planned model/evaluation and its limitations are quantified. A large but homogeneous dataset does not pass merely because of row count.
