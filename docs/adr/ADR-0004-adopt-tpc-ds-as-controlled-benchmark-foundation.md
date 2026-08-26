# ADR-0004 — Adopt TPC-DS as Controlled Benchmark Foundation

- Status: Accepted
- Date: 2026-08-25
- Decision owners: Human Tech Lead/Researcher

## Context

The project previously planned a custom ecommerce generator with `customers`, `products`, and `orders`, followed by custom Spark workloads. That direction provided control but required the project to design and maintain its own schema, distributions, generator semantics, and analytical coverage.

The Human Tech Lead approved replacing that benchmark-data/workload foundation with TPC-DS-generated data and project-controlled Spark materialization/workloads. The repository already contains an unbuilt TPC-DS DSGen 4.0.0 source tree, but its acquisition provenance, repository hygiene, build reproducibility, and licensing/distribution disposition have not yet been approved.

This decision must improve analytical coverage and reproducibility without changing the approved Spark-on-YARN infrastructure, collection path, execution-level modeling unit, feature leakage contract, ML formulation, evaluation protocol, optimization, or recommendation policy.

## Decision Drivers

- use a recognized analytical schema and relationship graph rather than maintaining a custom ecommerce schema;
- retain deterministic, versioned, inspectable benchmark inputs;
- provide scan, aggregation, join, multi-join, shuffle/sort, and complex SQL shapes;
- preserve source-to-dataset-to-experiment lineage;
- remain feasible on `LOCAL_YARN_V1` and within the eight-week research timebox;
- avoid any claim of an official or complete TPC-DS benchmark;
- address third-party toolkit provenance/licensing before implementation.

## Options Considered

### Option A — Continue the custom ecommerce generator and workloads

Pros:

- full control over generation and skew rules;
- no third-party build integration.

Cons:

- project-owned schema/distribution design burden;
- weaker analytical breadth and external recognizability;
- more custom correctness and maintenance work.

### Option B — TPC-DS-based controlled benchmark with selected tables and project workloads

Pros:

- established analytical schema and relationships;
- seed-controlled generator foundation intended for deterministic generation, with actual repeatability still requiring verification;
- supports multiple controlled Spark workload shapes;
- selected-table/materialization scope can remain feasible locally.

Cons:

- requires generator build, provenance, licensing, and materialization work;
- selected project workloads are not the official TPC-DS suite;
- local results remain environment-specific and non-comparable to official TPC results.

### Option C — Run and report an official complete TPC-DS benchmark

Pros:

- standardized complete benchmark procedure and official metrics when fully compliant.

Cons:

- outside the project's resource-recommendation research objective and local capacity/timebox;
- introduces compliance, disclosure, query-suite, refresh, power/throughput, and audit requirements not needed by the MVP;
- would redirect work away from Spark/YARN evidence collection and recommendation research.

## Decision

Select Option B.

1. Adopt this target flow:

   ```text
   TPC-DS
     -> dsdgen
     -> immutable raw generated data
     -> controlled materialization
     -> Parquet/Snappy on HDFS
     -> selected TPC-DS-derived analytical workloads
     -> Spark-on-YARN
     -> execution evidence
     -> historical execution dataset
     -> ML/recommendation
   ```

2. Use the terms **TPC-DS-based controlled benchmark** and **TPC-DS-derived analytical workloads**. Do not claim an official complete TPC-DS benchmark, official TPC-DS metrics, or comparability with official TPC Benchmark Results.

3. Define the initial dataset identities with version separate from ID:

   - `dataset_id = TPCDS_DEBUG`, `dataset_version = 1`;
   - `dataset_id = TPCDS_SF1`, `dataset_version = 1`.

   Dataset IDs do not embed `_V1`. Exact `TPCDS_DEBUG` derivation remains a future reviewed decision; no fractional scale or target size is assumed.

4. Materialize initially:

   - `store_sales`;
   - `item`;
   - `date_dim`;
   - `customer`;
   - `customer_address`;
   - `store`.

5. Preserve at least these relationship definitions:

   - `store_sales.ss_item_sk -> item.i_item_sk`;
   - `store_sales.ss_sold_date_sk -> date_dim.d_date_sk`;
   - `store_sales.ss_customer_sk -> customer.c_customer_sk`;
   - `store_sales.ss_addr_sk -> customer_address.ca_address_sk`;
   - `store_sales.ss_store_sk -> store.s_store_sk`.

6. Use these workload identities, each with separate `workload_version = 1`:

   - `W01_TPCDS_SCAN`;
   - `W02_TPCDS_AGG`;
   - `W03_TPCDS_JOIN`;
   - `W04_TPCDS_MULTI_JOIN`;
   - `W05_TPCDS_SHUFFLE_SORT`;
   - `W06_TPCDS_COMPLEX_SQL`.

7. Plan `W03_TPCDS_JOIN` as the Phase 1 bootstrap workload:

   ```text
   store_sales
     JOIN item
     JOIN date_dim
     -> aggregate by dimensions including d_year and i_category
   ```

   Exact join, aggregate, action, and correctness semantics must be approved before implementation.

8. Replace the planned bootstrap lineage with:

   ```text
   EXP_001
     -> LOCAL_YARN_V1
     -> TPCDS_DEBUG / dataset_version 1
     -> W03_TPCDS_JOIN / workload_version 1
     -> C1
   ```

   `C1` remains **TBD** and cannot be resolved until `LOCAL_YARN_V1` is human-reviewed and marked `VERIFIED`. This ADR does not authorize `EXP_001`.

9. Keep raw generation, materialization, workload execution, Spark/YARN collection, normalization, features, modeling, and recommendation as separate concerns. Preserve observed/missing metrics and all existing leakage/evaluation rules.

10. Do not select, build, relocate, clean, package, or execute the committed toolkit under this documentation task. A separate human gate must approve toolkit provenance, licensing, repository hygiene, integration option, and build contract.

## Relationship to ADR-0003

ADR-0003 remains unchanged as historical evidence of the local-environment and bootstrap decision at the time it was made.

This ADR supersedes only ADR-0003's custom benchmark dataset/workload foundation and the old bootstrap identifiers `DATA_DEBUG_V1` and `W03_JOIN_V1`. It does **not** supersede:

- `LOCAL_YARN_V1` topology or verification requirements;
- the Benchmark Bootstrap prerequisite and Phase 1/Phase 3 separation;
- `EXP_001`, source-observed `spark_application_id`, or later canonical `execution_id` identity boundaries;
- static allocation, AQE-off initial controls, or fixed recorded shuffle partitions;
- host-swap/background-load validity rules;
- environment-specific transfer limitations;
- the requirement for explicit human gate approval.

## Consequences

Positive:

- benchmark inputs use a broader analytical schema and relationship graph;
- dataset/workload lineage remains explicit and versioned;
- the initial suite covers six planned analytical shapes;
- later experiments can share one controlled foundation without claiming production representativeness.

Negative/trade-offs:

- toolkit provenance/licensing and reproducible build work become prerequisites;
- raw-to-Parquet schema and relationship validation must be implemented;
- `TPCDS_DEBUG` needs a safe deterministic definition;
- selected tables and project workloads do not constitute official TPC-DS;
- the initial suite does not yet guarantee controlled skew coverage.

## Validation / Revisit Trigger

Validate the decision through the independent gates in `../tpcds_implementation_plan.md` before any build, generation, materialization, workload, or bootstrap execution.

Revisit if licensing/provenance prevents an acceptable integration, the selected tables cannot support the required workload coverage, `TPCDS_DEBUG` cannot preserve the required semantics within local capacity, or the controlled benchmark cannot run safely on the verified environment. Any replacement must preserve old evidence and receive explicit Human Tech Lead approval.
