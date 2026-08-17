# Phase 4 — Dataset Freeze and Baselines

## Objective

Prepare leakage-safe train/validation/test data and establish strong non-ML baselines before model development.

## Required Outputs

- versioned dataset;
- data quality report;
- approved split protocol;
- frozen final test set;
- current/default baseline;
- nearest-history baseline;
- simple heuristic baseline;
- baseline evaluation report.

## Split Rules

- primary known-workload track: use within-family temporal cutoffs and strictly earlier history;
- secondary unseen-workload track: hold out complete `job_family_id` groups;
- keep Track A and Track B metrics separate;
- fit preprocessing on training data only.

## Agent Task Contract

```text
Prepare the dataset and baselines.

Required:
- version dataset
- summarize missing/outliers/duplicates/coverage
- propose and justify split strategy
- verify group/time separation
- freeze final test IDs
- implement current/default baseline
- implement nearest-history baseline
- implement simple transparent heuristic
- evaluate baselines with the same protocol

Do not tune the final ML model yet.
```

## Baseline Gate — PASS if

- [ ] Test set IDs/rule are frozen.
- [ ] Known-workload and unseen-workload tracks have distinct frozen identities and reports.
- [ ] Split leakage checks pass.
- [ ] Baselines are reproducible.
- [ ] Baseline metrics are recorded.
- [ ] Baseline algorithms are documented clearly enough to reimplement.
