# ADR-0003 — Local Benchmark Environment and Bootstrap

- Status: Accepted
- Date: 2026-08-22
- Decision owners: Human Tech Lead/Researcher

## Context

The project requires real Spark History Server/event-log and YARN evidence before the Phase 1 collector can be verified. Production history is not currently assumed, while the approved MVP provenance is synthetic benchmark execution. Existing architecture started at “Spark applications” and did not specify how the first reproducible applications would be produced.

The available research host has 16 GB physical RAM. The local environment must be useful for controlled evidence generation without being represented as a production cluster or treated as proof that local resource values transfer to company environments.

## Decision Drivers

- real, traceable Spark/YARN evidence for Phase 1;
- research validity and explicit provenance;
- reproducibility within the available host budget;
- minimal infrastructure needed to unblock implementation;
- clear separation between benchmark generation and the production recommender;
- future use of authorized company history without rewriting the core data contracts.

## Options Considered

### Option A — Wait for company/mentor history before collection implementation

Pros:

- data may be closer to the eventual target environment;
- avoids local infrastructure work.

Cons:

- blocks collector and end-to-end lineage work on an external dependency;
- exact source versions, completeness, and access timing are unknown;
- does not provide a controlled execution path for reproducible experiments.

### Option B — Single-host local Spark-on-YARN with synthetic benchmark bootstrap

Pros:

- produces real Spark jobs and real Spark/YARN metrics under controlled inputs;
- supports deterministic bootstrap and later systematic benchmarking;
- keeps synthetic provenance explicit;
- can later ingest company history through the same collection contracts.

Cons:

- two logical workers share one host and are not physically independent;
- the small capacity limits dataset/config coverage;
- results and recommended absolute resource values are environment-specific.

### Option C — Replace Spark/YARN evidence with mocked or simulated metrics

Pros:

- lowest setup cost;
- useful only for narrow parser/unit tests.

Cons:

- cannot satisfy the real/test execution trace required by the Data Gate;
- would not support observed runtime/resource claims;
- risks confusing fabricated outcomes with observations.

## Decision

Select Option B.

1. Create `LOCAL_YARN_V1` on a single personal workstation with 16 GB physical RAM.
2. Run two logical YARN NodeManagers on that host, initially **PLANNED** at approximately 2 vcores and 3 GB YARN memory per NodeManager. Actual capacities remain **TBD** until deployment measurement; the environment becomes **VERIFIED** only after the observed snapshot is reviewed.
3. Use HDFS, YARN ResourceManager, Spark History Server/event logs, deterministic synthetic data, versioned Spark workloads, and experiment specifications as a benchmark data-generation subsystem.
4. Add a Benchmark Bootstrap prerequisite before the Phase 1 end-to-end trace without creating or renumbering a phase.
5. Bootstrap with `DATA_DEBUG_V1` (approximately 100–300 MB), `W03_JOIN_V1`, and configuration ID `C1`. The executor count, executor cores, executor memory, overhead, driver/ApplicationMaster allowance, and shuffle partition count remain **TBD** until `LOCAL_YARN_V1` is **VERIFIED**. The resolved `C1` must be conservative, static, valid under observed YARN limits, and sufficient to complete the bootstrap workload.
6. Disable dynamic allocation and AQE for the initial controlled experiments. Fix and record `spark.sql.shuffle.partitions` within each experiment.
7. Assign `experiment_id = EXP_001` before submission, capture the source-observed `spark_application_id`, preserve Spark History/YARN raw evidence, and later assign a distinct canonical `execution_id` during normalization.
8. Treat detected host swap as invalid pending investigation and flag excessive background load.
9. Use Phase 3 for systematic/full benchmark generation; bootstrap runs alone do not satisfy the Dataset Gate.
10. Treat local models/recommendations as environment-specific. Production/company deployment requires target-environment history plus retraining or explicit calibration.

The benchmark subsystem creates research data. It is not part of the production recommendation runtime and does not fabricate metrics.

## Consequences

Positive:

- Phase 1 has a concrete, reproducible source execution.
- Dataset, workload, environment, and experiment identities become explicit.
- Later company evidence can use the same immutable collection and normalized contracts while retaining provenance.
- The project can move from architecture work to the smallest executable path.

Negative/trade-offs:

- local capacity constrains large-data and large-executor experiments;
- logical workers share host-level contention and failure domains;
- bootstrap adds infrastructure/data/workload code before collector completion;
- local absolute resource recommendations cannot be transferred directly to another cluster.

## Validation / Revisit Trigger

Validate this decision when:

- the exact environment snapshot is observed, reviewed, and marked **VERIFIED** as `LOCAL_YARN_V1`;
- `DATA_DEBUG_V1` is materialized and measured;
- `W03_JOIN_V1` completes on YARN;
- one application ID is correlated across Spark History/event-log and YARN evidence;
- `experiment_id = EXP_001` is linked to its `spark_application_id`, immutable raw artifacts, and anomaly observations; later normalization produces a distinct `execution_id`.

Revisit if the 16 GB host cannot run the minimum topology without swap, `C1` violates verified YARN constraints, required source evidence is unavailable, or target-environment history changes the transfer/calibration strategy.
