# Testing Strategy

## 1. Goal

Tests should protect research validity as well as software correctness. The most dangerous bugs are often silent schema/unit/leakage errors rather than crashes.

## 2. Unit Tests

Cover:

- unit conversion;
- duration/resource-cost formulas;
- feature transforms;
- historical cutoff logic;
- missing-value rules;
- candidate generation;
- Pareto dominance;
- recommendation policy;
- similarity distance calculation.

## 3. Contract / Schema Tests

For every source/parser:

- validate required fields/types;
- test missing optional fields;
- test unsupported/changed source shape;
- verify units;
- verify application ID mapping.
- validate raw manifest success/failure invariants and payload checksums.
- verify retries append artifacts rather than overwrite prior evidence.

Use representative sanitized fixtures.

## 4. Golden Parser Fixtures

Keep small immutable samples from supported Spark/YARN versions. A parser refactor should produce the same normalized output unless a schema migration is intentional.

## 5. Integration Tests

Where practical:

- History Server API -> raw store;
- YARN RM API -> raw store;
- raw -> normalized -> feature record;
- trained model -> candidate scoring;
- recommendation engine -> valid config.

External-cluster integration tests should be optional/skippable in local CI and never require production credentials.

## 6. Data Quality Tests

At dataset build time assert/monitor:

- unique `execution_id`;
- valid durations;
- positive resource sizes;
- status consistency;
- timestamps ordered correctly;
- no impossible utilization ratios;
- target non-null for training rows;
- no feature availability violation;
- group/time split integrity.
- Track A temporal-cutoff integrity and Track B family isolation.

## 7. ML Tests

Test properties rather than exact floating-point scores:

- training is reproducible within tolerance;
- model can load serialized artifact;
- inference schema rejects missing required inputs;
- predictions are finite/non-negative for runtime;
- pipeline does not fit preprocessors on test data;
- baseline and model consume the same frozen test protocol.

## 8. Optimization Invariants

- every recommended config belongs to valid candidate space;
- cluster limits are never exceeded;
- dominated candidates are not mislabeled Pareto-optimal;
- recommendation is deterministic for identical inputs/model/policy;
- `NO_SAFE_RECOMMENDATION` is possible when no candidate satisfies constraints.

## 9. E2E Smoke Test

A minimal end-to-end test should exercise:

```text
sample raw fixture
 -> normalization
 -> features
 -> model inference
 -> candidate search
 -> recommendation
 -> explanation payload
```

The final demo should also have a manually verified smoke script using at least one actual captured Spark execution.
