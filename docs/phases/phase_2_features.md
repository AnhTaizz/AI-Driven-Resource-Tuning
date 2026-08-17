# Phase 2 — Normalization and Feature Engineering

## Objective

Transform immutable raw Spark/YARN data into deterministic canonical records and model-ready features without target leakage.

## Required Outputs

- normalized execution schema implementation;
- feature extraction pipeline;
- one feature record per target execution;
- auditable `as_of_timestamp` for every modeling record;
- feature dictionary/lineage;
- missing-data policy;
- leakage review;
- unit/data-quality tests.

## Mandatory Design Review

Before implementing features, classify every candidate feature as:

- PRE_RUN;
- HISTORICAL_ONLY;
- CANDIDATE_CONFIG;
- POST_RUN_TARGET.

Same-run post-execution metrics cannot be model inputs for a pre-submit recommendation model.

## Agent Task Contract

```text
Implement normalization and feature engineering only.

Before coding:
1. enumerate proposed features;
2. assign availability class;
3. identify leakage risks;
4. define units/source/lineage/missing handling;
5. propose deterministic transformations.

Implement:
- raw -> normalized transformations
- normalized -> execution-level features
- strictly historical aggregations
- tests for time cutoffs and units
- feature metadata/version

Do not train models or implement recommendation logic.
```

## Feature Gate — PASS if

- [ ] One execution-level feature record is produced reproducibly.
- [ ] Every model feature has definition, unit, source, availability, transform, and missing policy.
- [ ] Historical aggregates exclude the target/future execution.
- [ ] Each modeling record is reproducible using only evidence available by its `as_of_timestamp`.
- [ ] Preprocessing leakage risks are documented.
- [ ] Raw data remains unchanged.
- [ ] Feature transforms pass tests.
- [ ] Feature lineage can be demonstrated for a sample execution.
