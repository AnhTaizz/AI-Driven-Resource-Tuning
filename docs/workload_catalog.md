# Spark Workload Catalog

## 1. Purpose

This catalog defines stable Spark jobs for reproducible local experiments. A workload version fixes its logical transformations, action/materialization boundary, required inputs, and controlled settings. Resource configurations vary in experiment specs, not inside workload code.

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

AQE-enabled or materially changed workload logic requires a distinct experiment series or workload version.

## 3. W01_FILTER_V1

- **Purpose:** low-shuffle ETL/filter/projection reference.
- **Input tables:** `orders`.
- **Transformations:** filter to a documented date/status predicate; project stable order/customer/product/amount fields; derive a documented amount bucket.
- **Expected Spark behavior:** scan and narrow transformations with little or no wide shuffle before output materialization.
- **Action/materialization:** write the filtered projection to an experiment-specific output path and record output row count/bytes.
- **Controlled settings:** fixed predicate, selected columns, output format, compression, AQE state, and output partition rule.
- **Version:** `V1`.

## 4. W02_AGGREGATION_V1

- **Purpose:** measure group-by aggregation and moderate shuffle behavior.
- **Input tables:** `orders`, `customers` when region is required.
- **Transformations:** join customer region if needed; group by documented date bucket, region, and order status; compute order count, total quantity, total amount, and average amount.
- **Expected Spark behavior:** wide aggregation shuffle with bounded output cardinality.
- **Action/materialization:** write the aggregate table and validate aggregate row count plus total-order-count reconciliation.
- **Controlled settings:** grouping keys, aggregation formulas, date range, join semantics, shuffle partitions, and AQE state.
- **Version:** `V1`.

## 5. W03_JOIN_V1

- **Purpose:** bootstrap and measure a representative multi-table join followed by aggregation.
- **Input tables:** `orders`, `customers`, `products`.
- **Transformations:** `orders JOIN customers` on `customer_id`; join `products` on `product_id`; group by `(region, category)`; compute order count, total quantity, and total order amount.
- **Expected Spark behavior:** join exchanges as selected by Spark under controlled settings, followed by a group-by shuffle.
- **Action/materialization:** write grouped results to an experiment-specific path; record output row count and reconcile aggregate order count with joined input rows.
- **Controlled settings:** inner-join semantics, no broadcast hint in V1, fixed filters, fixed shuffle partitions, AQE off, dynamic allocation off, and consistent output format/compression.
- **Version:** `V1`.

`W03_JOIN_V1` is the bootstrap workload for `EXP_001` with `DATA_DEBUG_V1` and configuration `C1` from `benchmark_plan.md`.

## 6. W04_SHUFFLE_HEAVY_V1

- **Purpose:** exercise high data movement without intentionally fabricating a failure.
- **Input tables:** `orders`.
- **Transformations:** repartition by a documented high-cardinality key; perform a keyed aggregation; repartition/sort the aggregate by a second documented key before output.
- **Expected Spark behavior:** multiple wide exchanges, elevated shuffle read/write, and sensitivity to cores/executors/shuffle partitions.
- **Action/materialization:** write the final sorted/partitioned aggregate and validate row counts/checksums.
- **Controlled settings:** repartition keys/count, sort keys, aggregation formulas, shuffle partitions, AQE state, and output format.
- **Version:** `V1`.

The exact repartition count must be declared in the experiment/workload config; it must not silently follow a changing default.

## 7. W05_SKEW_JOIN_V1

- **Purpose:** measure observed effects of a known, generated key distribution skew.
- **Input tables:** `orders` with `SKEWED` distribution, `customers`, optionally `products` if declared by the experiment.
- **Transformations:** join `orders` to `customers` on `customer_id`; group by region and a documented key-derived bucket; aggregate counts and amounts.
- **Expected Spark behavior:** imbalanced shuffle partitions/tasks caused by measured hot-key frequency, with possible spill/straggler evidence depending on configuration.
- **Action/materialization:** write aggregate output and record per-key/input distribution evidence plus output validation.
- **Controlled settings:** dataset skew definition/version, join semantics, no skew hint in V1, fixed shuffle partitions, AQE off, dynamic allocation off, and output format.
- **Version:** `V1`.

Skew, spill, OOM, and failure must be observed from real execution. The generator may create a documented skewed distribution, but experiment records may not invent outcome labels.

## 8. Versioning and Change Control

- Changing only candidate resources does not change the workload version.
- Changing transformations, join semantics, predicates, grouping keys, hints, materialization semantics, or correctness checks creates a new workload version.
- Changing AQE or other execution behavior controls requires a separately labeled experiment series and may require a workload version when semantics/plan assumptions change.
- Preserve prior workload code/configs needed to reproduce recorded experiments.
