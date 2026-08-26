# Spark Workload Catalog — TPC-DS-Derived Analytical Workloads

## 1. Purpose and Status

This catalog defines the **approved initial workload identities and planning boundaries** for the TPC-DS-based controlled benchmark. Only the six IDs and the W03 bootstrap shape supplied in ADR-0004 are approved; all non-W03 inputs/logic below are candidates awaiting their workload-contract gates. No workload has been implemented or executed.

These are project-defined **TPC-DS-derived analytical workloads**. They are not presented as the complete official TPC-DS workload, and no workload is mapped to an official TPC-DS query number unless a later reviewed contract explicitly establishes that mapping.

## 2. Identity and Versioning

Workload identity and version are separate fields. Workload IDs must not embed `_V1`.

| `workload_id` | `workload_version` | Initial family | Status |
|---|---:|---|---|
| `W01_TPCDS_SCAN` | `1` | scan/filter/projection | `PLANNED` |
| `W02_TPCDS_AGG` | `1` | aggregation | `PLANNED` |
| `W03_TPCDS_JOIN` | `1` | join plus aggregation; bootstrap | `PLANNED` |
| `W04_TPCDS_MULTI_JOIN` | `1` | multi-dimension join | `PLANNED` |
| `W05_TPCDS_SHUFFLE_SORT` | `1` | shuffle and sort | `PLANNED` |
| `W06_TPCDS_COMPLEX_SQL` | `1` | complex Spark SQL | `PLANNED` |

## 3. Common Execution Contract

Every future workload execution must record:

- `workload_id` and separate `workload_version`;
- input `dataset_id`, separate `dataset_version`, and dataset manifest reference;
- code revision and exact workload-spec reference;
- exact input table/path set;
- output/action, output location, and correctness evidence;
- resolved Spark configuration, including AQE, dynamic allocation, broadcast threshold, and shuffle partitions where applicable;
- Spark application ID and experiment ID;
- semantic validation status and anomaly notes.

Common initial controls remain:

- static allocation only;
- AQE disabled for the initial controlled series;
- `spark.sql.shuffle.partitions` explicitly resolved and fixed within a comparable experiment;
- no silent use of cached results between measured executions;
- output fully materialized to an experiment-specific path or another reviewed action boundary;
- Parquet/Snappy output where a workload writes tabular results;
- workload logic and input dataset version fixed while resource configurations are compared;
- correctness checks completed before an execution becomes eligible for benchmark/model data.

Exact SQL, predicates, projections, aggregate expressions, join types, hints, action boundaries, and correctness checks must be frozen at the Workload Contract Review Gate before implementation. Expected Spark behavior below is design intent, never an observed metric or outcome.

## 4. `W01_TPCDS_SCAN` — Version 1

- **Purpose:** provide the initial low-complexity scan/filter/projection reference.
- **Candidate input:** `store_sales`; final input selection is TBD.
- **Candidate behavior:** bounded projection and predicate logic over the fact table without a project-inserted shuffle.
- **Contract still required:** exact columns, predicate, null semantics, action/output, and correctness check.

## 5. `W02_TPCDS_AGG` — Version 1

- **Purpose:** exercise a controlled keyed aggregation over TPC-DS-derived data.
- **Candidate inputs:** `store_sales` and, only if later approved, one selected dimension table.
- **Candidate behavior:** group and aggregate selected sales measures under fixed shuffle controls.
- **Contract still required:** exact input set, grouping keys, aggregate formulas, null/decimal handling, action/output, and reconciliation check.

## 6. `W03_TPCDS_JOIN` — Version 1

- **Purpose:** serve as the Phase 1 bootstrap workload and provide a representative fact-to-dimension join followed by aggregation.
- **Planned inputs:** `store_sales`, `item`, and `date_dim`.
- **Required relationship path:**

  ```text
  store_sales.ss_item_sk = item.i_item_sk
  store_sales.ss_sold_date_sk = date_dim.d_date_sk
  ```

- **Planned aggregation dimensions:** `date_dim.d_year` and `item.i_category`.
- **Controlled settings:** no unreviewed join hint; fixed `spark.sql.autoBroadcastJoinThreshold`; fixed shuffle partitions; AQE off; dynamic allocation off.
- **Contract still required:** exact join type, predicate, aggregate expressions, output schema/action, null handling, and input-to-output correctness reconciliation.

The planned bootstrap lineage is:

```text
EXP_001
  -> LOCAL_YARN_V1
  -> TPCDS_DEBUG / dataset_version 1
  -> W03_TPCDS_JOIN / workload_version 1
  -> C1
```

`C1` remains **TBD**. Human verification of `LOCAL_YARN_V1` is complete for the approved snapshot, but `C1` requires a separate explicit review and Human approval. This catalog does not authorize implementation or execution of the bootstrap.

## 7. `W04_TPCDS_MULTI_JOIN` — Version 1

- **Purpose:** exercise a wider selected-dimension join graph than W03.
- **Candidate inputs:** `store_sales` plus a future-reviewed subset of `item`, `date_dim`, `customer`, `customer_address`, and `store`.
- **Candidate behavior:** join through only relationships approved in `benchmark_data_spec.md`, then materialize a deterministic analytical result.
- **Contract still required:** exact table subset, join order-independent logical semantics, join types, filters, grouping/measure expressions, action/output, and relationship/count checks.

## 8. `W05_TPCDS_SHUFFLE_SORT` — Version 1

- **Purpose:** exercise explicitly controlled wide exchange and sort behavior without fabricating spill, skew, OOM, or failure.
- **Candidate input:** `store_sales`, with dimensions only if later approved by the result contract.
- **Candidate behavior:** deterministic repartition/aggregation/sort operations tied to the experiment's resolved shuffle-partition setting.
- **Contract still required:** keys, projections, aggregate expressions, sort semantics, action/output, and reconciliation check.

The name describes intended transformations only. Runtime, shuffle bytes, spill, task imbalance, and resource use must come from observed Spark/YARN evidence.

## 9. `W06_TPCDS_COMPLEX_SQL` — Version 1

- **Purpose:** provide a more complex analytical SQL shape using only the selected initial tables.
- **Candidate inputs:** a future-reviewed subset of the six selected tables.
- **Candidate behavior:** a deterministic multi-operator SQL plan distinct from W01–W05.
- **Contract still required:** whether it is project-authored or mapped to a specific official template, exact SQL, all parameters, action/output, and correctness oracle.

Until a mapping is reviewed, describe W06 only as TPC-DS-derived project SQL, not an official TPC-DS query.

## 10. Coverage Limitation

The initial six-workload plan has no dedicated workload whose name or contract guarantees controlled skew. Dataset and execution profiling must quantify any observed key/task imbalance. If coverage is insufficient, add a separately reviewed dataset/workload version later; never fabricate skew or relabel normal variability as a designed skew case.

## 11. Change Control

- Changing only candidate resource values does not change `workload_version`.
- Changing transformations, predicates, join semantics, grouping/aggregate logic, hints, action/materialization semantics, or correctness checks requires a new workload version.
- Changing AQE or other execution-plan controls requires a separately labeled experiment series and may require a new workload version.
- Preserve prior workload code/configuration needed to reproduce recorded experiments.
- No workload may move from `PLANNED` to an implemented/verified state without the review sequence in `tpcds_implementation_plan.md`.
