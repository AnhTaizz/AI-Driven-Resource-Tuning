# Synthetic Data Specification — SYNTHETIC_ECOMMERCE_V1

## 1. Purpose and Provenance

This document defines the **APPROVED** V1 synthetic schema and distribution contract processed by local Spark workloads. It makes benchmark inputs deterministic and reproducible; it does not claim to reproduce company production data.

All generated datasets have provenance `SYNTHETIC_BENCHMARK`. They may be joined with later company execution history only after source/environment provenance remains explicit.

## 2. Domain

Use one stable ecommerce domain with exactly three V1 tables. Additional columns or semantic changes require a new schema/dataset version.

### `customers`

| Field | Type | Notes |
|---|---|---|
| `customer_id` | long | stable primary key |
| `region` | string | bounded categorical value |
| `customer_type` | string | bounded categorical value |
| `age` | int | positive customer age generated under the V1 generator rules |

### `products`

| Field | Type | Notes |
|---|---|---|
| `product_id` | long | stable primary key |
| `category` | string | bounded categorical value |
| `price` | double | positive deterministic value |

### `orders`

| Field | Type | Notes |
|---|---|---|
| `order_id` | long | stable primary key |
| `customer_id` | long | foreign key to `customers` |
| `product_id` | long | foreign key to `products` |
| `quantity` | int | positive bounded value |
| `amount` | double | deterministically derived from quantity and referenced product price |
| `event_timestamp` | timestamp | deterministic UTC timestamp |

All V1 fields are non-null. Generator code must publish the category vocabularies, value ranges, timestamp range, and exact amount formula with its `generator_version`. Those rules are part of reproducibility metadata; changing schema or distribution semantics increments `dataset_version` or `generator_version` as appropriate.

## 3. Generator Parameters

Every materialization resolves and records at least:

```text
seed
num_customers
num_products
num_orders
distribution
hot_key_fraction
hot_record_fraction
num_partitions
output_path
```

- `seed` controls every pseudo-random choice; no unseeded randomness is allowed.
- `distribution` is exactly `NORMAL` or `SKEWED`.
- `hot_key_fraction` and `hot_record_fraction` are null for `NORMAL` and required for `SKEWED`.
- `num_partitions` is the requested materialization partition count, not an implicit runtime default; the actual physical partition/file count is measured after writing.
- `output_path` is a versioned HDFS dataset root. A verified dataset path must not be overwritten.
- Referential integrity must be deterministic and checked after generation.

V1 materialization settings are fixed:

```text
output_format = PARQUET
compression = SNAPPY
```

### 3.1 Distribution Definitions

For `NORMAL`, order `customer_id` and `product_id` references are sampled uniformly from their valid key spaces using the resolved seed. `hot_key_fraction` and `hot_record_fraction` are null.

For `SKEWED`:

1. deterministically select the hot customer-ID set using a seeded shuffle;
2. calculate `hot_key_count = max(1, floor(num_customers * hot_key_fraction))`;
3. assign exactly `floor(num_orders * hot_record_fraction)` order records uniformly across the hot customer IDs using the resolved seed;
4. assign the remaining order records uniformly across the non-hot customer IDs using the resolved seed;
5. sample product IDs using the normal V1 rule unless a later dataset version explicitly defines product skew.

The standard V1 skew profile is:

```text
hot_key_fraction = 0.01
hot_record_fraction = 0.50
```

This means 1% of customer IDs receive 50% of order records. Alternative skew values require a distinct dataset identity/configuration and must be recorded in the manifest. Valid SKEWED parameters satisfy `0 < hot_key_fraction < 1`, `hot_key_fraction < hot_record_fraction <= 1`, and leave at least one non-hot customer ID.

## 4. Dataset Identity and Manifest

Each generated dataset has a manifest containing:

| Field | Meaning |
|---|---|
| `dataset_id` | stable identity such as `DATA_DEBUG_V1` |
| `dataset_version` | semantic version of the materialized dataset contract |
| `generator_version` | generator code/spec version |
| `seed` | resolved random seed |
| `distribution` | `NORMAL` or `SKEWED` under the V1 definition |
| `row_count` | measured total rows across materialized tables |
| `row_count_by_table` | measured rows for each table |
| `actual_size_bytes` | measured total materialized bytes across tables |
| `actual_size_bytes_by_table` | measured materialized bytes per table |
| `partition_count` | measured total physical partitions/files |
| `partition_count_by_table` | measured physical partitions/files per table |
| `hot_key_fraction` | resolved value or null for `NORMAL` |
| `hot_record_fraction` | resolved value or null for `NORMAL` |
| `output_format` | `PARQUET` |
| `compression` | `SNAPPY` |
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

Only `DATA_DEBUG_V1` is named for bootstrap. Dataset artifacts remain **PLANNED** until materialized; their row counts, partition counts, seeds, and actual sizes are observed metadata rather than assumed values. IDs and exact target sizes for the full benchmark are resolved only after the **VERIFIED** environment establishes a safe feasibility envelope.

## 6. Materialization and Verification

1. Resolve a versioned generator configuration.
2. Generate each table deterministically.
3. Materialize as Parquet with Snappy compression to the versioned HDFS `output_path` without overwriting a previously verified dataset.
4. Read the materialized output back to measure rows, bytes, partitions, and schema.
5. Validate primary/foreign-key expectations and distribution/skew statistics.
6. Write the immutable dataset manifest.
7. Reference the manifest from each experiment record.

Failed/partial generations remain separate from verified datasets and cannot reuse an existing verified `dataset_id`.

## 7. Leakage and Modeling Boundary

Dataset identity, generator version, and seed are lineage metadata. They are not automatically eligible model features. Only fields listed and reviewed in `feature_schema.md` may enter a model, and `actual_input_size_bytes` is used only when genuinely available before the recommended run.
