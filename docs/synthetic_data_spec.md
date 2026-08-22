# Synthetic Data Specification

## 1. Purpose and Provenance

This document defines the synthetic business-shaped data processed by local Spark workloads. It makes benchmark inputs deterministic and reproducible; it does not claim to reproduce company production data.

All generated datasets have provenance `SYNTHETIC_BENCHMARK`. They may be joined with later company execution history only after source/environment provenance remains explicit.

## 2. Domain

Use one stable retail/order domain with three tables:

### `customers`

| Field | Type | Notes |
|---|---|---|
| `customer_id` | long | stable primary key |
| `region` | string | bounded categorical value |
| `customer_segment` | string | bounded categorical value |
| `created_date` | date | deterministic from seed/key |

### `products`

| Field | Type | Notes |
|---|---|---|
| `product_id` | long | stable primary key |
| `category` | string | bounded categorical value |
| `unit_price` | decimal | positive deterministic value |

### `orders`

| Field | Type | Notes |
|---|---|---|
| `order_id` | long | stable primary key |
| `customer_id` | long | foreign key to `customers` |
| `product_id` | long | foreign key to `products` |
| `order_date` | date | deterministic from seed/order ID |
| `quantity` | int | positive bounded value |
| `order_status` | string | bounded categorical value |
| `order_amount` | decimal | deterministic from quantity/price rule |

Generator code must publish exact data types, nullability, category vocabularies, and formulas with its generator version. Schema or distribution changes increment `dataset_version` or `generator_version` as appropriate.

## 3. Generator Parameters

Every materialization resolves and records at least:

```text
seed
num_customers
num_products
num_orders
skew_factor
num_partitions
output_format
```

- `seed` controls every pseudo-random choice; no unseeded randomness is allowed.
- `skew_factor` must have a versioned mathematical definition. `NORMAL` data uses the documented neutral value.
- `num_partitions` is the materialized input partition count, not an implicit runtime default.
- Referential integrity must be deterministic and checked after generation.

## 4. Dataset Identity and Manifest

Each generated dataset has a manifest containing:

| Field | Meaning |
|---|---|
| `dataset_id` | stable identity such as `DATA_DEBUG_V1` |
| `dataset_version` | semantic version of the materialized dataset contract |
| `generator_version` | generator code/spec version |
| `seed` | resolved random seed |
| `distribution` | `NORMAL` or `SKEWED` with definition version |
| `row_count` | measured total rows across materialized tables |
| `row_count_by_table` | measured rows for each table |
| `actual_size_bytes` | measured total materialized bytes across tables |
| `actual_size_bytes_by_table` | measured materialized bytes per table |
| `partition_count_by_table` | measured physical partitions/files per table |
| `skew_factor` | resolved generation parameter |
| `output_format` | e.g. Parquet plus relevant options |
| `data_uri_refs` | non-secret HDFS paths or artifact references |
| `content_hashes` | integrity evidence where practical |
| `created_at` | generation timestamp |
| `code_revision` | repository revision that produced it |
| `benchmark_environment_id` | environment used for materialization |

Planned size is never substituted for measured size. `SMALL`, `MEDIUM`, and `LARGE` are labels. Each experiment derives and records `actual_input_size_bytes` from the materialized tables/paths actually read by that workload; downstream normalization maps it to `input_size_bytes` only when it is genuinely available before submission and its source is documented.

## 5. Initial Dataset Profiles

| Dataset/scale | Target size | Distribution | Intended use |
|---|---:|---|---|
| `DATA_DEBUG_V1` / `DEBUG` | 100–300 MB | `NORMAL` | bootstrap and pipeline debugging |
| `SMALL` | about 500 MB | `NORMAL`, optionally `SKEWED` | low local load |
| `MEDIUM` | about 1–2 GB | `NORMAL`, `SKEWED` | central local load |
| `LARGE` | initially about 3–5 GB | `NORMAL`, `SKEWED` where safe | upper feasibility exploration |

Only `DATA_DEBUG_V1` is named/fixed for bootstrap. IDs, row counts, partition counts, seeds, and exact target sizes for the full benchmark remain proposed until the verified environment establishes a safe feasibility envelope.

## 6. Materialization and Verification

1. Resolve a versioned generator configuration.
2. Generate each table deterministically.
3. Materialize to a versioned HDFS location without overwriting prior frozen datasets.
4. Read the materialized output back to measure rows, bytes, partitions, and schema.
5. Validate primary/foreign-key expectations and distribution/skew statistics.
6. Write the immutable dataset manifest.
7. Reference the manifest from each experiment record.

Failed/partial generations remain separate from verified datasets and cannot share a frozen `dataset_id`.

## 7. Leakage and Modeling Boundary

Dataset identity, generator version, and seed are lineage metadata. They are not automatically eligible model features. Only fields listed and reviewed in `feature_schema.md` may enter a model, and `actual_input_size_bytes` is used only when genuinely available before the recommended run.
