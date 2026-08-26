# Historical Execution Data Contract

## 1. Scope

The canonical unit of observation is **one Spark application execution**. Stage/task/executor records may exist as child tables, but the modeling dataset must preserve a stable execution-level key.

This file defines normalized records. Immutable collector payloads and their manifests are governed separately by `raw_data_contract.md`.

## 2. Identity and Lineage

Required canonical fields:

| Field | Type | Required | Unit/Format | Source | Notes |
|---|---|---:|---|---|---|
| `execution_id` | string | yes | stable project ID | derived | Never reuse across distinct executions |
| `experiment_id` | string | yes for benchmark runs | experiment record ID | experiment | Links to the exact experiment specification/record |
| `spark_application_id` | string | yes | Spark app ID | Spark/YARN | Primary cross-source correlation key |
| `application_attempt_id` | string/null | no | YARN attempt ID | YARN | Needed for retries/attempts |
| `job_family_id` | string/null | no | project-defined | derived/manual | Stable workload family, not execution ID |
| `workload_id` | string/null | yes for benchmark runs | catalog ID | experiment | e.g. `W03_TPCDS_JOIN`; keep `workload_version` separate and do not infer from app name |
| `workload_version` | string/null | yes for benchmark runs | version | experiment | Logical workload definition version |
| `dataset_id` | string/null | yes for benchmark runs | dataset ID | dataset manifest | Stable materialized input identity |
| `dataset_version` | string/null | yes for benchmark runs | version | dataset manifest | Materialized dataset contract/version |
| `dataset_generator_version` | string/null | no | version | dataset manifest | Lineage metadata, not a default ML feature |
| `dataset_seed` | int/null | no | integer | dataset manifest | Lineage metadata, not a default ML feature |
| `experiment_repeat_index` | int/null | yes for repeated benchmark runs | zero- or one-based per experiment contract | experiment | Index convention must be documented and stable |
| `application_name` | string/null | no | text | Spark/YARN | Treat as potentially sensitive |
| `started_at` | timestamp | yes | UTC internally | Spark/YARN | Preserve timezone on ingestion |
| `finished_at` | timestamp/null | no | UTC internally | Spark/YARN | Null for incomplete execution |
| `collection_timestamp` | timestamp | yes | UTC | collector | |
| `benchmark_environment_id` | string | yes | versioned ID | environment | Resolves exact Spark/Hadoop/Java/Python/deployment metadata |
| `source_versions` | object/string | yes | versions | environment | Spark/Hadoop/parser versions |
| `raw_record_refs` | array/string | yes | paths/IDs | collector | Trace back to immutable raw payload |

## 3. Workload Fields

| Field | Type | Required | Unit | Availability | Notes |
|---|---|---:|---|---|---|
| `input_size_bytes` | int/null | preferred | bytes | PRE_RUN or HISTORICAL_ONLY | Source must be documented; do not infer blindly |
| `input_partitions` | int/null | no | count | PRE_RUN/HISTORICAL_ONLY | |
| `num_stages` | int/null | no | count | POST_RUN_TARGET for same run | Can be historical context for next run |
| `num_tasks` | int/null | no | count | POST_RUN_TARGET for same run | |
| `shuffle_read_bytes` | int/null | no | bytes | POST_RUN_TARGET | historical context only for recommendation |
| `shuffle_write_bytes` | int/null | no | bytes | POST_RUN_TARGET | |
| `records_read` | int/null | no | count | POST_RUN_TARGET | |
| `records_written` | int/null | no | count | POST_RUN_TARGET | |
| `skew_indicator` | float/null | no | documented ratio | DERIVED | Definition/version required |
| `workload_type` | string/null | no | category | PRE_RUN/manual | e.g. ETL, join, aggregation, shuffle-heavy |

## 4. Spark Resource Configuration

| Field | Type | Required | Unit | Availability |
|---|---|---:|---|---|
| `num_executors` | int/null | yes for fixed allocation | count | CANDIDATE_CONFIG / observed config |
| `executor_cores` | int | yes | cores | CANDIDATE_CONFIG |
| `executor_memory_bytes` | int | yes | bytes | CANDIDATE_CONFIG |
| `executor_memory_overhead_bytes` | int/null | no | bytes | CANDIDATE_CONFIG |
| `driver_memory_bytes` | int/null | no | bytes | CANDIDATE_CONFIG |
| `dynamic_allocation_enabled` | bool | yes | boolean | PRE_RUN |
| `min_executors` | int/null | no | count | PRE_RUN |
| `max_executors` | int/null | no | count | PRE_RUN |
| `aqe_enabled` | bool | yes for benchmark runs | boolean | PRE_RUN/config |
| `configured_shuffle_partitions` | int/null | preferred | count | PRE_RUN/config |

If dynamic allocation is enabled, do not pretend a single static `num_executors` fully describes resource usage. Preserve actual executor timeline/aggregate metrics where available.

Static allocation is the supported MVP recommendation mode. Dynamic-allocation executions may remain in collection/analysis data, but they must not enter the MVP candidate space or be evaluated with static-allocation cost approximations as if equivalent.

`aqe_enabled` and `configured_shuffle_partitions` are execution controls/lineage. They are not automatically eligible model inputs; feature eligibility is governed by `feature_schema.md`.

## 5. Environment Registry Boundary

`benchmark_environment_id` resolves a versioned environment registry/snapshot containing host/runtime and cluster capacity details such as:

- exact Spark, Hadoop/YARN, Java, Python, and image/distribution versions;
- logical/physical topology;
- NodeManager and total cluster vcore/memory capacity;
- scheduler and allocation boundaries;
- environment-specific instrumentation/quality capabilities.

Do not duplicate these relatively static capacity fields into every normalized execution row unless a downstream data contract requires a versioned snapshot join. For future cross-environment modeling, derive environment-relative features from the execution plus its resolved registry record and review them under `feature_schema.md`.

## 6. Observed Outcome Fields

| Field | Type | Required | Unit | Origin |
|---|---|---:|---|---|
| `runtime_ms` | int | yes for completed run | ms | OBSERVED |
| `status` | enum | yes | SUCCEEDED/FAILED/KILLED/UNKNOWN | OBSERVED |
| `oom_detected` | bool/null | no | boolean | OBSERVED/parsed |
| `memory_spill_bytes` | int/null | no | bytes | OBSERVED |
| `disk_spill_bytes` | int/null | no | bytes | OBSERVED |
| `peak_executor_memory_bytes` | int/null | no | bytes | OBSERVED |
| `executor_cpu_time_ms` | int/null | no | ms | OBSERVED |
| `executor_run_time_ms` | int/null | no | ms | OBSERVED |
| `executor_utilization_ratio` | float/null | no | 0..1 | DERIVED |
| `allocated_vcore_ms` | int/null | no | vcore-ms | DERIVED/OBSERVED depending source |
| `allocated_memory_mb_ms` | int/null | no | MB-ms | DERIVED/OBSERVED depending source |
| `observed_driver_memory_bytes` | int/null | no | bytes | OBSERVED/configured boundary |
| `observed_application_master_memory_bytes` | int/null | no | bytes | OBSERVED/configured boundary |

## 7. Derived Cost Fields

Prefer storing raw ingredients and recomputing costs by formula version.

Examples:

```text
executor_hours = effective_executor_count * runtime_hours
memory_gb_hours = effective_executor_count
                  * (executor_memory_gb + executor_memory_overhead_gb)
                  * runtime_hours
vcore_hours = effective_executor_count * executor_cores * runtime_hours
```

If YARN provides better aggregate allocation metrics for the environment, use them and document the formula/source.

For observed validation, prefer validated YARN time-integrated memory and vCore allocation metrics. Report driver/ApplicationMaster cost separately unless an approved metric version explicitly includes it. Do not combine memory and vCore into a single score without an approved weighting policy.

## 8. Missingness

Do not use magic values such as `-1`, `0`, or empty string to mean missing unless the source naturally uses that value and the contract documents it.

Recommended companion fields for important optional metrics:

- `<field>_missing_reason`
- `source_quality_flags`

Possible reasons:

- `NOT_EXPOSED_BY_SOURCE`
- `NOT_APPLICABLE`
- `PARSER_UNSUPPORTED_VERSION`
- `COLLECTION_FAILED`
- `EXECUTION_INCOMPLETE`

## 9. Child Tables

Where useful, maintain normalized child tables:

- `stage_execution`
- `sql_execution`
- `task_summary`
- `executor_summary`
- `yarn_application_attempt`
- `yarn_container_summary`

The execution-level modeling table should be built from these with documented aggregation logic.

Minimum concurrency lineage where exposed:

| Child | Required identity/timing fields | Notes |
|---|---|---|
| `sql_execution` | `execution_id`, `sql_execution_id`, `started_at`, `finished_at` | Missing timing remains explicit |
| `stage_execution` | `execution_id`, `stage_id`, `stage_attempt_id`, `started_at`, `finished_at`, `sql_execution_id` nullable | Preserve retry attempts |
| `executor_summary` | `execution_id`, `executor_id`, added/removed timestamps where available | Resource evidence remains application-scoped |
| `yarn_application_attempt` | `execution_id`, `application_attempt_id`, timestamps/status | Do not collapse retries silently |
| `yarn_container_summary` | `application_attempt_id`, `container_id`, timestamps/allocation where available | Supports validated allocation aggregation |

Concurrency features are derived from interval overlap. Never sum SQL/stage durations as application wall-clock time, and never treat a SQL/stage record as an independently allocated YARN application.

## 10. Modeling Snapshot Boundary

Every training/evaluation row must record an `as_of_timestamp`. `PRE_RUN` values and `HISTORICAL_ONLY` aggregates must be reconstructable using only information available strictly before this timestamp. Same-execution SQL/stage/shuffle/spill/utilization records remain post-run observations for that execution.

## 11. Schema Evolution

- version the schema (`execution_schema_version`);
- changes to meaning/unit require a major schema version;
- adding optional fields can be minor version;
- parser changes require golden-fixture tests;
- never reinterpret an existing field without migration documentation.
