# Metric Catalog

## Purpose

This file is the single source of truth for metric meaning and formulas. Code, dashboards, experiment reports, and the final thesis/report must use the same definitions.

## Observed Metrics

### `observed_runtime_ms`

- Definition: application completion time minus start time for the target execution.
- Unit: milliseconds.
- Source priority: use one authoritative source consistently for evaluation; document fallback.

### `observed_memory_spill_bytes`

- Definition: total memory spill associated with the execution under the approved aggregation rule.
- Unit: bytes.

### `observed_disk_spill_bytes`

- Definition: total disk spill associated with the execution under the approved aggregation rule.
- Unit: bytes.

### `observed_status`

- Values: `SUCCEEDED`, `FAILED`, `KILLED`, `UNKNOWN`.

### `observed_executor_utilization_ratio`

- Definition: a versioned post-run diagnostic derived from validated executor CPU-time and executor run-time semantics for the supported Spark source.
- Unit: ratio in `[0, 1]`.
- Formula when source semantics are validated:

```text
sum(executor_cpu_time_ms) / sum(executor_run_time_ms)
```

- Do not compute when the numerator/denominator semantics, coverage, or units are incompatible; record missingness instead.
- This is not a direct measure of whole-cluster utilization or executor idle percentage. Any idle warning threshold must name its rule version and limitations.

### `observed_peak_executor_memory_bytes`

- Definition: maximum supported executor peak-memory observation under a named source/aggregation rule.
- Unit: bytes.
- Do not conflate JVM heap, process RSS, peak execution memory, and YARN container allocation. Record the exact source field and semantic boundary.

## Derived Resource Metrics

The exact effective executor-count formula depends on static vs dynamic allocation. Never use a static formula for dynamic allocation without documenting approximation error.

### `derived_executor_hours`

Static-allocation approximation:

```text
num_executors * runtime_ms / 3_600_000
```

### `derived_executor_memory_gb_hours`

Static-allocation approximation:

```text
num_executors
* (executor_memory_bytes + executor_memory_overhead_bytes) / 1024^3
* runtime_ms / 3_600_000
```

This is an executor-only static-allocation approximation. Driver/ApplicationMaster memory is excluded and must be reported separately unless a later metric version explicitly includes it.

### `derived_vcore_hours`

Static-allocation approximation:

```text
num_executors
* executor_cores
* runtime_ms / 3_600_000
```

If YARN exposes time-integrated allocation metrics suitable for the environment, prefer those after validation.

### `observed_yarn_memory_gb_hours`

When Hadoop/YARN exposes a validated time-integrated memory-allocation metric:

```text
allocated_memory_mb_ms / 1024 / 3_600_000
```

Record whether the source includes ApplicationMaster/container allocation and the exact Hadoop field semantics.

### `observed_yarn_vcore_hours`

When Hadoop/YARN exposes a validated time-integrated vCore-allocation metric:

```text
allocated_vcore_ms / 3_600_000
```

Observed YARN metrics are preferred for final validation. Static derived metrics remain fallbacks and must not be mixed under the same metric name.

## Post-run Diagnostic Rules

OOM, spill, low-utilization, peak-memory-pressure, and skew warnings are rule-based for the MVP. Each emitted diagnostic records:

- rule version and threshold;
- observed evidence and source metric;
- source/aggregation version;
- severity;
- missing/uncertain evidence;
- limitation that the diagnostic is post-run, not a live intervention.

## Comparison Metrics

### `runtime_change_pct`

```text
(recommended_observed_runtime - baseline_observed_runtime)
/ baseline_observed_runtime * 100
```

Positive means slower than baseline; negative means faster.

### `resource_saving_pct`

```text
(baseline_resource_cost - recommended_resource_cost)
/ baseline_resource_cost * 100
```

Positive means resource saving.

### `regret_pct`

When the best observed feasible candidate is known:

```text
(selected_objective - best_observed_objective)
/ best_observed_objective * 100
```

Define the exact objective before using regret.

## Reporting Rules

- Never mix predicted and observed values in the same metric without labeling.
- State whether cost is executor-hours, memory-GB-hours, vcore-hours, or another metric.
- Do not report a single “resource saving” number without naming the underlying resource metric.
- Keep raw values available next to percentages.
- Keep executor-only, driver/ApplicationMaster, and YARN-inclusive cost boundaries distinguishable.
- Never combine memory-GB-hours and vCore-hours into an unlabeled scalar score.
