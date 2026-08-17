# Phase 7 — Real Spark Validation

## Objective

Demonstrate whether recommendations improve resource efficiency in actual Spark executions on frozen hold-out workloads.

## Required Comparisons

Where feasible:

1. current/default config;
2. heuristic/similar-history baseline;
3. ML recommendation.

## Procedure

- use frozen test workloads;
- do not retrain/tune from final test outcomes;
- record exact config/environment;
- repeat important runs when budget allows;
- capture raw Spark/YARN evidence;
- calculate resource/runtime deltas from observed values.

## Agent Task Contract

```text
Execute the final validation protocol exactly as frozen.

For each test workload/config:
- create experiment record
- run the approved configuration
- collect observed runtime/resource/reliability
- note anomalies/cluster contention
- preserve raw outputs

Report all valid cases, including those where the recommendation is worse.
Do not tune on the final test set.
```

## Validation Gate — PASS if

- [ ] Recommended configs have actually run on Spark.
- [ ] Observed baseline and recommendation metrics exist.
- [ ] Resource-saving/runtime-change calculations are traceable.
- [ ] Reliability/spill/failure behavior is reported.
- [ ] Negative cases are not hidden.
- [ ] Limitations for new/unseen workloads are stated.
