# Phase 3 — Benchmark and Data Generation

## Objective

Create a diverse, reproducible execution history when production data is insufficient, without wasting compute on a blind Cartesian grid.

## Required Outputs

- benchmark workload definitions;
- experiment matrix;
- configuration ranges;
- experiment IDs/records;
- raw captured outputs for each run;
- data coverage/profiling report.

## Workload Coverage

Target, where practical:

- ETL/filter/project;
- aggregation;
- join-heavy;
- shuffle-heavy;
- skewed workloads;
- multiple input scales.

## Agent Task Contract

```text
Design the benchmark before executing it.

First produce:
- workload families and rationale
- input scales
- candidate resource ranges
- expected under/normal/over-provisioned regions
- total run estimate
- redundancy reduction strategy
- replication/noise-control plan

After approval, execute runs and record every experiment using the experiment template.

Do not fabricate failure/OOM cases.
Do not run disruptive stress cases on a shared cluster without permission.
```

## Dataset Gate — PASS if

- [ ] Workload diversity is quantified.
- [ ] Resource-config diversity is quantified.
- [ ] Sparse/uncovered regions are known.
- [ ] Repeated-run noise is sampled for important cases.
- [ ] Synthetic/benchmark data is clearly labeled.
- [ ] Experiment metadata is complete enough to reproduce runs.
