# Phase 1 — Historical Data Collection

## Objective

Collect trustworthy historical execution data from Spark/YARN sources while preserving raw payloads and source lineage.

## Prerequisite — Benchmark Bootstrap

This prerequisite does **not** change phase numbering. It creates the minimum real/test Spark-on-YARN execution required to exercise the Phase 1 collection path; it is not the systematic Phase 3 benchmark.

- [ ] Local Spark-on-YARN environment runs.
- [ ] HDFS is accessible.
- [ ] Spark History Server is accessible and event logging is configured.
- [ ] YARN ResourceManager evidence is accessible.
- [ ] One TPC-DS-based controlled debug dataset exists (`dataset_id = TPCDS_DEBUG`, `dataset_version = 1`).
- [ ] One reviewed TPC-DS-derived Spark workload exists (`workload_id = W03_TPCDS_JOIN`, `workload_version = 1`).
- [ ] One Spark application can complete and return a Spark application ID.

The bootstrap experiment is assigned `experiment_id = EXP_001` before submission and binds `LOCAL_YARN_V1`, `TPCDS_DEBUG` version `1`, `W03_TPCDS_JOIN` version `1`, and the human-approved `C1`. Spark/YARN then supplies `spark_application_id`; Phase 1 preserves the corresponding raw evidence. Phase 2 normalization later assigns the canonical `execution_id`. One to five bootstrap executions may be used to resolve environment or collection issues. They are collector fixtures/evidence, not Dataset Gate coverage. This phase contract does not authorize the build/generation/materialization steps or `EXP_001`; follow `docs/tpcds_implementation_plan.md` first.

## Scope

- Spark History Server REST integration;
- Spark EventLog parsing where REST is insufficient/useful;
- YARN ResourceManager REST integration;
- immutable raw storage;
- raw artifact manifests and integrity checks;
- source/version metadata;
- logging/error handling;
- contract/golden tests.

## Required Outputs

- collector modules;
- raw directory/layout;
- `raw_v1` manifest implementation conforming to `docs/raw_data_contract.md`;
- source configuration template;
- sanitized example payloads/fixtures;
- application-ID correlation logic;
- missing-metric/source-capability report;
- tests;
- at least one end-to-end trace.

## Key Rules

- pin/record actual Spark and Hadoop/YARN versions;
- pin the full `benchmark_environment_id` snapshot before version-sensitive parser behavior;
- never fabricate fields absent from source;
- preserve raw payload before normalization;
- hash successful payload artifacts and append retry artifacts rather than overwrite;
- use canonical time/byte units only after normalization;
- keep credentials outside repo;
- bounded retry only for transient failures.

## Agent Task Contract

```text
Implement only the historical data collection phase.

Before coding:
1. read PROJECT_STATE.md and architecture/data schema docs;
2. inspect repository structure;
3. verify the Benchmark Bootstrap prerequisite;
4. verify the deployed Spark-on-YARN environment and record exact Spark/Hadoop/Java/Python/image versions;
5. list target endpoints/sources and version assumptions;
6. propose the smallest collector design.

Implement:
- Spark History Server collector
- YARN ResourceManager collector
- EventLog parser only where justified
- immutable raw persistence
- raw manifest/checksum implementation
- source metadata
- logging and explicit errors
- tests/fixtures

Do not implement feature engineering, ML, optimization, or UI.
```

## Data Gate — PASS if

- [ ] Spark data is collected from a real/test execution.
- [ ] YARN data is collected from the same real/test Spark-on-YARN execution used for the end-to-end trace.
- [ ] Spark/YARN application identity can be correlated or limitations are documented.
- [ ] Raw payloads are preserved.
- [ ] Successful raw artifacts have valid manifests and SHA-256 checksums; retries do not overwrite evidence.
- [ ] Missing metrics are explicit.
- [ ] Source/version metadata exists.
- [ ] `benchmark_environment_id` resolves exact Spark/Hadoop/Java/Python/deployment metadata.
- [ ] Parser/collector tests pass.
- [ ] One execution can be traced source -> raw artifact.

The agent cannot self-approve this gate.
