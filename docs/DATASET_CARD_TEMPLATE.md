# Dataset Card — <dataset version>

## Summary

- Dataset version:
- Created date:
- Source period:
- Source environments:
- Benchmark environment IDs:
- Number of executions:
- Number of workload/job families:

## Purpose

What model/evaluation is this dataset intended for?

## Sources

- Spark History Server:
- Spark Event Logs:
- YARN ResourceManager:
- Synthetic/benchmark workloads:

Clearly separate real-company and simulated/benchmark data.

## Unit of Observation

One Spark application execution.

## Schema Versions

- raw schema:
- normalized schema:
- feature set:

## Coverage

- workload families:
- input scale distribution:
- resource config distribution:
- successful/failed/OOM/spill counts:
- repeated-run coverage:

## Missingness

List important missing metrics and reasons.

## Split Protocol

### Track A — Known-workload next-run

- temporal cutoff rule:
- eligible workload families:
- train IDs/range:
- validation IDs/range:
- frozen test IDs/range:

### Track B — Unseen-workload robustness

- group key/rule:
- training family IDs:
- validation family IDs:
- frozen test family IDs:

## Known Biases / Limitations

Examples:

- synthetic workloads dominate;
- little coverage for unseen job families;
- limited OOM positives;
- local environment differs from production cluster.

## Intended / Prohibited Uses

Intended:

- research prototype training/evaluation.

Prohibited unless separately validated:

- automatic production resource changes;
- claims about workload families absent from the data.
