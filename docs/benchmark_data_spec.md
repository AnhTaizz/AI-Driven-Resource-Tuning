# Benchmark Data Specification — TPC-DS-Based Controlled Benchmark

## 1. Status, Purpose, and Claim Boundary

This document defines the **approved planning contract** for benchmark input data after adoption of TPC-DS as the controlled benchmark foundation. No dataset described here has been generated or materialized yet.

The project uses the following terms:

- **TPC-DS-based controlled benchmark** for the overall research benchmark;
- **TPC-DS-derived analytical workloads** for the project-defined Spark workloads.

The project is **not** running or claiming an official complete TPC-DS benchmark. It does not execute the complete official workload, calculate or publish official TPC-DS metrics, or claim that its results are comparable to official TPC Benchmark Results. All generated executions remain synthetic, local, environment-specific research evidence rather than company production evidence.

The planned data path is:

```text
Pinned TPC-DS toolkit source
  -> reviewed dsdgen build and invocation
  -> immutable raw generated data
  -> controlled schema/relationship validation and materialization
  -> selected tables as Parquet/Snappy on HDFS
  -> TPC-DS-derived analytical workloads
```

Generation, materialization, workloads, and Spark execution are separate concerns. Raw `dsdgen` output must not be overwritten or confused with the Parquet dataset consumed by Spark.

## 2. Initial Dataset Identities

Dataset identity and version are separate fields. Dataset IDs must not embed `_V1`.

| `dataset_id` | `dataset_version` | Intended role | Current status |
|---|---:|---|---|
| `TPCDS_DEBUG` | `1` | Phase 1 bootstrap and pipeline debugging | `PLANNED`; exact deterministic derivation is TBD |
| `TPCDS_SF1` | `1` | Initial scale-factor-1 controlled dataset for later benchmark coverage | `PLANNED`; not generated or measured |

`TPCDS_SF1` means this project's selected-table materialization derived from a reviewed `dsdgen` scale-factor-1 generation. It does not imply that the project materializes or executes the complete official TPC-DS database or query suite.

`TPCDS_DEBUG` is a distinct debug dataset identity. The committed generator accepts integer scale values, so this document does not assume a fractional scale factor. Its exact generation/subsetting method, generator parameters, relationship-preservation rules, and expected feasibility envelope require approval at the Dataset Definition Review Gate in `tpcds_implementation_plan.md`.

Planned size is never substituted for measured size. Row counts, raw bytes, Parquet bytes, file counts, and partition counts remain unavailable until materialization and must then be recorded as observed metadata.

## 3. Initial Selected Tables

The first materialized scope contains:

- `store_sales`;
- `item`;
- `date_dim`;
- `customer`;
- `customer_address`;
- `store`.

The initial relationship map includes:

| Fact field | Dimension field |
|---|---|
| `store_sales.ss_item_sk` | `item.i_item_sk` |
| `store_sales.ss_sold_date_sk` | `date_dim.d_date_sk` |
| `store_sales.ss_customer_sk` | `customer.c_customer_sk` |
| `store_sales.ss_addr_sk` | `customer_address.ca_address_sk` |
| `store_sales.ss_store_sk` | `store.s_store_sk` |

The relationship map defines join lineage, not an unverified claim that every fact foreign key is non-null or matched. Materialization verification must measure null and unmatched counts according to the reviewed TPC-DS schema semantics and preserve the observed results.

Adding tables or changing selected fields, parsing rules, or relationship semantics requires a new dataset version or a separately reviewed materialization-spec version, depending on whether the materialized dataset contract changes.

## 4. Generation Contract

Every future generation must resolve and record at least:

- `dataset_id` and `dataset_version`;
- TPC-DS toolkit version and immutable source reference;
- reviewed toolkit acquisition/provenance reference;
- build environment and build command;
- generated `dsdgen` binary hash plus every required runtime build artifact, including the generated `tpcds.idx` distribution index and its effective `DISTRIBUTIONS` path;
- exact generator invocation and all effective parameters, including scale, output directory, table selection, parallel/child settings, RNG seed, delimiter, suffix, `DISTRIBUTIONS`, `TERMINATE`, `FORCE`, and `QUIET` where applicable;
- raw generated artifact references, byte sizes, and cryptographic hashes;
- generation start/end timestamps and status;
- code revision and responsible environment identity.

Defaults must not remain implicit in a reproducible experiment record. If an upstream concept is unavailable or not applicable, record it explicitly as missing rather than inventing a value.

Whether generation emits the full TPC-DS table set or only the initial selected tables is **TBD**. That choice must be reviewed together with relationship integrity and reproducibility before generator integration is implemented.

## 5. Raw Generated Data Boundary

Raw generated data is immutable evidence of a particular reviewed generator build and invocation.

- Store each generation under a unique, versioned artifact reference.
- Resolve a new empty output directory outside the vendored source/build tree; reject symlink/path escape and any non-empty/existing artifact target.
- Never overwrite a verified raw generation.
- Do not use `FORCE` to overwrite verified or partial generation artifacts.
- Preserve exact file hashes and the generator log/manifest.
- Keep failed or partial generations separate and mark their status explicitly.
- Do not silently repair, sample, cast, or normalize raw generator output in place.
- Never invoke the toolkit's upstream tests or cleanup scripts as part of generation.
- Do not treat raw generator output as Spark/YARN execution evidence; Spark/YARN evidence remains governed by `raw_data_contract.md`.

The toolkit's `dbgen_version` output can include generation date/time and command-line metadata. Repeatability must therefore be defined at the Dataset Definition Gate: compare approved analytical table content with a reviewed order-independent method, pin relevant time zone/environment inputs, and preserve any non-deterministic metadata exactly rather than normalizing raw files in place. The exact raw storage location and retention mechanism are implementation decisions for a later review gate. This planning task does not create directories or artifacts.

## 6. Controlled Materialization Contract

The approved target representation is:

```text
output_format = PARQUET
compression = SNAPPY
storage = HDFS
```

Materialization must be deterministic from the immutable raw generation plus a versioned materialization specification. It must:

1. parse using an explicit schema mapped to the pinned toolkit/specification;
2. materialize only the approved table scope;
3. write to a versioned HDFS path without overwriting a verified dataset;
4. read the result back and measure schema, rows, files, partitions, and bytes;
5. validate the five initial relationships with explicit null/unmatched reporting;
6. record Parquet/Snappy settings and all effective Spark/materialization configuration;
7. write an immutable dataset manifest with source-to-materialized lineage.

Exact schemas, null handling, date/decimal mappings, partition strategy, HDFS paths, and correctness thresholds remain **TBD** until the Materialization Contract Review Gate. They must be verified against TPC-DS 4.0.0 source/specification before implementation.

## 7. Dataset Manifest

Each verified materialization must record at least:

| Field | Meaning |
|---|---|
| `dataset_id` | `TPCDS_DEBUG` or `TPCDS_SF1` for the initial design |
| `dataset_version` | separate version value, initially `1` |
| `benchmark_provenance` | explicit non-production TPC-DS-based controlled label; exact serialized value approved at D1 |
| `toolkit_version` | observed generator source/binary version |
| `toolkit_source_ref` | immutable source/archive/tree reference |
| `generator_build_ref` | build manifest, binary digest, `tpcds.idx`/runtime-artifact digests, and effective distribution path |
| `generator_invocation_ref` | exact reviewed invocation/effective parameters |
| `raw_generation_refs` | immutable raw artifacts and hashes |
| `materialization_spec_version` | version of parse/schema/write rules |
| `selected_tables` | exact materialized table list |
| `row_count_by_table` | measured materialized row counts |
| `actual_size_bytes_by_table` | measured materialized bytes |
| `partition_count_by_table` | measured physical files/partitions |
| `schema_by_table` | observed materialized schema reference |
| `relationship_check_results` | observed null/unmatched/key validation summary |
| `output_format` | `PARQUET` |
| `compression` | `SNAPPY` |
| `data_uri_refs` | non-secret versioned HDFS references |
| `content_hashes` | integrity evidence where practical |
| `created_at` | materialization timestamp |
| `code_revision` | repository revision used |
| `benchmark_environment_id` | materialization environment, initially verified `LOCAL_YARN_V1`; materialization remains separately gated |
| `status` | explicit lifecycle state under the future manifest contract; exact enum approved before implementation |

The exact serialization schema is a future implementation artifact. This document does not change the normalized execution-level schema in `data_schema.md`.

## 8. Workload Input Accounting

Each experiment must reference the dataset manifest and list the exact table/path inputs actually read. `actual_input_size_bytes` is derived from the materialized inputs selected by that workload only when it is genuinely available before submission and its derivation is documented.

Toolkit version, generator parameters, dataset identity, and materialization settings are lineage metadata. They are not automatically eligible model features. Feature eligibility and same-run leakage rules remain governed by `feature_schema.md`.

## 9. Known Limitations and Open Decisions

- `TPCDS_DEBUG` derivation is not yet defined.
- Full-table versus selected-table raw generation is not yet chosen.
- The `dsdgen` build and runtime have not been verified.
- No initial dataset row count, byte size, file count, or relationship-check result has been observed.
- Initial workload coverage does not guarantee a controlled skew case; skew must be profiled from observed data/executions and never asserted from the workload name.
- The committed toolkit's provenance, public redistribution compliance, and future packaging require human review as described in `tpcds_implementation_plan.md`.
