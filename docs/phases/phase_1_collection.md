# Phase 1 — Historical Data Collection

## Objective

Collect trustworthy historical execution data from Spark/YARN sources while preserving raw payloads and source lineage.

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
3. verify the deployed Spark-on-YARN environment and record exact Spark/Hadoop/Java/Python/image versions;
4. list target endpoints/sources and version assumptions;
5. propose the smallest collector design.

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
