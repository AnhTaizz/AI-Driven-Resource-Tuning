# EXP-XXXX — <short title>

## Metadata

- `status`: PLANNED
- `experiment_id`:
- Date:
- Owner:
- Git revision:
- `dataset_id` / `dataset_version`:
- `dataset_generator_version`:
- `dataset_seed`:
- `dataset_manifest_ref`:
- `workload_id` / `workload_version`:
- `experiment_repeat_index`:
- `feature_set_version`:
- `model_version`:
- `benchmark_environment_id`:
- `environment_snapshot_ref`:
- `spark_application_id`:
- `execution_id` (after normalization):
- `raw_artifact_refs`:
- `random_seed`:
- `host_swap_observed`: true/false/unknown
- `background_load_flag`:

Static Spark/Hadoop/Java/Python versions, image digest, topology, and NodeManager capacity resolve through the environment snapshot. Do not manually duplicate them here. Source-observed versions required for raw provenance remain in the raw artifact manifests.

## Research Question

What exact question does this experiment answer?

## Hypothesis

State a falsifiable hypothesis.

## Workload

- Workload family:
- Workload ID/version:
- Input dataset ID/version:
- Actual input size:
- Input row/partition counts:
- Special characteristics (join/skew/shuffle/etc.):

## Spark Configuration

```yaml
num_executors:
executor_cores:
executor_memory:
driver_memory:
executor_memory_overhead:
dynamic_allocation_enabled:
aqe_enabled:
configured_shuffle_partitions:
```

## Procedure

1.
2.
3.

## Observed Results

| Metric | Value | Unit | Source |
|---|---:|---|---|
| runtime | | ms | Spark/YARN |
| memory spill | | bytes | Spark |
| disk spill | | bytes | Spark |
| executor/vcore resource | | | |
| status | | | |

## Derived Results

| Metric | Value | Formula/version |
|---|---:|---|
| executor-hours | | |
| memory-GB-hours | | |
| vcore-hours | | |

## Prediction / Recommendation

If applicable:

- predicted runtime:
- predicted risk:
- recommended config:
- model/policy version:

## Anomalies

List contention, cache effects, collection failures, retries, or anything that may invalidate interpretation.

## Conclusion

What does the evidence support? What does it not support?

## Follow-up

Next experiment/decision, if any.
