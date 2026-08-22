# Spark Workload Catalog

## 1. Purpose

This catalog defines the **APPROVED** Spark workload logic for the initial V1 benchmark suite. A workload version fixes its logical transformations, action/materialization boundary, required inputs, and controlled settings. Resource configurations vary in experiment specs, not inside workload code.

## 2. Common Contract

Every workload execution records:

- `workload_id` and `workload_version`;
- input `dataset_id`/`dataset_version` and manifest reference;
- code revision;
- output/action and output row count or checksum where practical;
- resolved Spark configuration, including AQE, dynamic allocation, and shuffle partitions;
- Spark application ID and experiment ID;
- any semantic validation failure.

Common initial controls:

- static allocation only;
- AQE disabled for the initial controlled series;
- `spark.sql.shuffle.partitions` explicitly set and fixed within an experiment;
- workload logic and input data fixed while resource configurations are compared;
- output written to an experiment-specific path or otherwise fully materialized;
- no silent use of cached results between measured runs.
- output format fixed to Parquet with Snappy compression;
- correctness checks complete before an execution is eligible for benchmark/model data.

AQE-enabled or materially changed workload logic requires a distinct experiment series or workload version.

## 3. W01_FILTER_V1

- **Purpose:** low-shuffle ETL/filter/projection reference.
- **Input tables:** `orders`.
- **Transformations:** read `orders`; filter `quantity >= 2`; project `(order_id, customer_id, product_id, amount, event_timestamp)` without adding derived columns.
- **Expected Spark behavior:** scan/filter/projection reference composed of narrow transformations before the output action.
- **Action/materialization:** write the projected rows as Parquet/Snappy to the experiment-specific output path; record output row count and bytes.
- **Controlled settings:** predicate and projected columns above, input dataset version, AQE state, dynamic-allocation state, and output path.
- **Version:** `V1`.

## 4. W02_AGGREGATION_V1

- **Purpose:** measure group-by aggregation and moderate shuffle behavior.
- **Input tables:** `orders` only.
- **Transformations:** `groupBy(customer_id)`; calculate `count(*) AS order_count`, `sum(amount) AS total_amount`, and `avg(amount) AS average_amount`.
- **Expected Spark behavior:** keyed aggregation with a wide exchange before materialization.
- **Action/materialization:** write `(customer_id, order_count, total_amount, average_amount)` as Parquet/Snappy; validate that `sum(order_count)` equals the input order count.
- **Controlled settings:** grouping key and formulas above, input dataset version, fixed shuffle partitions, AQE off, and dynamic allocation off.
- **Version:** `V1`.

## 5. W03_JOIN_V1

- **Purpose:** bootstrap and measure a representative multi-table join followed by aggregation.
- **Input tables:** `orders`, `customers`, `products`.
- **Transformations:** inner join `orders` to `customers` on `customer_id`; inner join the result to `products` on `product_id`; `groupBy(region, category)`; calculate `count(*) AS order_count`, `sum(quantity) AS total_quantity`, and `sum(amount) AS total_amount`.
- **Expected Spark behavior:** two joins under a fixed broadcast-threshold setting followed by a keyed aggregation exchange.
- **Action/materialization:** write grouped results to an experiment-specific path; record output row count and reconcile aggregate order count with joined input rows.
- **Controlled settings:** inner-join semantics, no explicit broadcast hint, `spark.sql.autoBroadcastJoinThreshold` fixed within comparable experiments, fixed shuffle partitions, AQE off, dynamic allocation off, and Parquet/Snappy output.
- **Version:** `V1`.

`W03_JOIN_V1` is the bootstrap workload for `experiment_id = EXP_001` with `DATA_DEBUG_V1` and configuration ID `C1` from `benchmark_plan.md`. The numeric values of `C1` remain TBD until the environment is VERIFIED.

## 6. W04_SHUFFLE_HEAVY_V1

- **Purpose:** exercise high data movement without intentionally fabricating a failure.
- **Input tables:** `orders`.
- **Transformations:** repartition `orders` to `configured_shuffle_partitions` by `customer_id`; `groupBy(customer_id, product_id)`; calculate `count(*) AS order_count`, `sum(quantity) AS total_quantity`, and `sum(amount) AS total_amount`; repartition the aggregate to `configured_shuffle_partitions` by `product_id`; `sortWithinPartitions(product_id, customer_id)`.
- **Expected Spark behavior:** multiple explicitly controlled wide exchanges and a high-cardinality keyed aggregation.
- **Action/materialization:** write the final sorted aggregate as Parquet/Snappy; validate that `sum(order_count)` equals the input order count.
- **Controlled settings:** repartition keys and counts above, aggregation/sort keys above, fixed shuffle partitions, AQE off, and dynamic allocation off.
- **Version:** `V1`.

The exact repartition count equals the experiment's resolved `configured_shuffle_partitions`; it must not silently follow a changing runtime default.

## 7. W05_SKEW_JOIN_V1

- **Purpose:** provide a controlled skewed-join workload for studying customer-key distribution and task-imbalance conditions.
- **Input tables:** `orders` with the V1 `SKEWED` customer-key distribution and `customers`.
- **Transformations:** repartition `orders` to `configured_shuffle_partitions` by `customer_id`; inner join `orders` to `customers` on `customer_id`; `groupBy(region, customer_type)`; calculate `count(*) AS order_count`, `sum(amount) AS total_amount`, and `avg(amount) AS average_amount`.
- **Expected Spark behavior:** designed to create controlled customer-key distribution skew and task-imbalance conditions during the customer-key exchange/join path.
- **Action/materialization:** write the aggregate as Parquet/Snappy; record the input distribution manifest and validate that `sum(order_count)` equals the joined order count.
- **Controlled settings:** V1 skew definition and resolved fractions, repartition key/count, inner-join semantics, no skew/broadcast hint, fixed `spark.sql.autoBroadcastJoinThreshold`, fixed shuffle partitions, AQE off, and dynamic allocation off.
- **Version:** `V1`.

Only the input key distribution and transformation structure are prescribed. Runtime, task-duration imbalance, spill, OOM, failure, and other performance outcomes must be observed from real execution and must never be invented by the workload contract.

## 8. Versioning and Change Control

- Changing only candidate resources does not change the workload version.
- Changing transformations, join semantics, predicates, grouping keys, hints, materialization semantics, or correctness checks creates a new workload version.
- Changing AQE or other execution behavior controls requires a separately labeled experiment series and may require a workload version when semantics/plan assumptions change.
- Preserve prior workload code/configs needed to reproduce recorded experiments.
