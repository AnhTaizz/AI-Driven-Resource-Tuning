# Phase 3 — Benchmark and Data Generation

## Objective

Create a diverse, reproducible execution history when production data is insufficient, without wasting compute on a blind Cartesian grid.

Phase 3 is the **systematic/full benchmark generation phase**. It is not the first point at which the project runs Spark:

```text
Benchmark Bootstrap (before/during Phase 1)
  -> 1–5 executions for environment and collector traceability

Phase 3
  -> dozens or, only if justified, hundreds of executions
  -> coverage for dataset construction, baselines, and ML
```

Bootstrap runs may be retained with complete lineage, but they do not by themselves satisfy Phase 3 coverage or the Dataset Gate.

Full systematic Phase 3 benchmark execution begins only after the Phase 1 collection path is working and the Data Gate has been approved. This does not prohibit implementing the minimal dataset generator, workload, runner, and environment foundation required for the Phase 1 Benchmark Bootstrap.

## Required Outputs

- benchmark workload definitions;
- experiment matrix;
- configuration ranges;
- experiment IDs/records;
- raw captured outputs for each run;
- data coverage/profiling report;
- explicit separation of bootstrap/debug runs from the systematic coverage matrix.

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
- versioned workload IDs from `docs/workload_catalog.md`
- versioned dataset IDs/scales from `docs/synthetic_data_spec.md`
- candidate resource ranges
- expected under/normal/over-provisioned regions
- total run estimate
- redundancy reduction strategy
- replication/noise-control plan
- host swap/background-load validity rules

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
