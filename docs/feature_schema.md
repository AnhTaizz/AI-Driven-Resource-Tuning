# Feature Schema and Leakage Contract

## 1. Purpose

This document defines what may enter a model at recommendation time. It is stricter than the raw data schema because many Spark metrics are only known after an execution finishes.

## 2. Availability Classes

- `PRE_RUN`: available before the target execution starts.
- `HISTORICAL_ONLY`: derived only from executions strictly earlier than the target execution, or from a training-only similar-job corpus.
- `CANDIDATE_CONFIG`: configuration currently being evaluated.
- `POST_RUN_TARGET`: same-run outcome; never a same-run model input.

Every modeling row must include an `as_of_timestamp`. Availability is evaluated relative to this timestamp, not merely by table membership.

## 3. Feature Contract Template

Every feature must document:

| Property | Description |
|---|---|
| name | Stable snake_case feature name |
| definition | Exact semantic meaning |
| dtype | Numeric/categorical/boolean |
| unit | Canonical unit |
| source | Raw/normalized fields used |
| availability | PRE_RUN / HISTORICAL_ONLY / CANDIDATE_CONFIG / POST_RUN_TARGET |
| transform | Formula/aggregation |
| missing handling | Explicit policy |
| leakage risk | Why safe at inference time |
| version | Feature definition version |

## 4. Initial Feature Set

### 4.1 Pre-run / Workload Context

Candidate features, only when truly available before submit:

- `input_size_bytes`
- `input_partitions`
- `workload_type`
- `job_family_id` encoded appropriately
- user-declared operation class / benchmark family

Do not assume data size is known for every production job. If it is estimated, record `input_size_estimation_method` and keep estimated vs observed values separate.

### 4.2 Historical Context

Examples calculated from earlier runs only:

- `hist_runtime_median_ms`
- `hist_runtime_p90_ms`
- `hist_shuffle_read_median_bytes`
- `hist_shuffle_write_median_bytes`
- `hist_memory_spill_rate`
- `hist_disk_spill_rate`
- `hist_peak_memory_p90_bytes`
- `hist_executor_utilization_median`
- `hist_failure_rate`
- `hist_num_stages_median`
- `hist_num_tasks_median`
- `hist_runs_count`

Each history feature must define the lookback scope and exclude the target execution.

For the primary known-workload track, history may include strictly earlier executions of the same `job_family_id`. For the unseen-workload track, target-family history is unavailable; similar-job retrieval must be fitted only on the training-family corpus.

### 4.3 Candidate Configuration Features

- `candidate_num_executors`
- `candidate_executor_cores`
- `candidate_executor_memory_bytes`
- `candidate_driver_memory_bytes`
- `candidate_executor_memory_overhead_bytes`
- `candidate_total_cores`
- `candidate_total_executor_memory_bytes`

Derived interaction features may include:

- `bytes_per_executor`
- `bytes_per_core`
- `historical_shuffle_bytes_per_executor_memory_byte`

Only add interactions if they are interpretable and validated.

### 4.4 Targets

Required:

- `target_runtime_ms`

Optional:

- `target_failed`
- `target_oom`
- `target_memory_spill_bytes`
- `target_disk_spill_bytes`

Targets are never copied into the input matrix for the same row.

## 5. Leakage Review Checklist

Before training:

- [ ] No same-execution runtime-derived input feature exists.
- [ ] No same-execution stage/task/shuffle/spill metric is used unless the use case explicitly assumes a partial-run/feedback scenario and has a separate model/protocol.
- [ ] Historical aggregates are computed with strict time cutoff.
- [ ] Every row has an auditable `as_of_timestamp`.
- [ ] Similar-job retrieval is built only from the allowed training/history pool.
- [ ] Train/test grouping prevents near-duplicate executions from leaking across splits.
- [ ] Preprocessing is fitted on training data only.
- [ ] Target encoding, normalization, imputation, and feature selection are inside the training pipeline.

## 6. Feature Versioning

Recommended format:

```text
feature_set_version: fs_v1
feature_code_revision: <git sha>
source_schema_version: execution_v1
```

Any semantic change to a feature increments the feature-set version and triggers model re-evaluation.
