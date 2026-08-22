# EXP-XXXX — <short title>

## Metadata

- Status: PLANNED
- Date:
- Owner:
- Git revision:
- Dataset ID/version:
- Dataset generator version:
- Dataset seed:
- Dataset manifest reference:
- Workload ID/version:
- Experiment repeat index:
- Feature-set version:
- Model version:
- Environment:
- Spark version:
- Hadoop/YARN version:
- Benchmark environment ID:
- Deployment image/distribution version or digest:
- Java/Python versions:
- Random seed:
- Host swap observed: true/false/unknown
- Background-load quality flag:

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
spark_sql_shuffle_partitions:
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
