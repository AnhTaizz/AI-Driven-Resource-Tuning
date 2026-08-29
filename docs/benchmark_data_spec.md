# Benchmark Data Specification — TPC-DS-Based Controlled Benchmark

## 1. Status, Purpose, and Claim Boundary

This document defines the **Human-approved D1 generation/derivation contract**
for benchmark input data after adoption of TPC-DS as the controlled benchmark
foundation. The contract was frozen from the reviewed TPC-DS Tools / DSGen 4.0.0
source and locally verified P04B artifacts. D2 generated and verified the
canonical `TPCDS_SF1` version 1 raw parent, which the Human approved on
`2026-08-29`. D3 freezes the debug reduction size; no `TPCDS_DEBUG` derivation or
materialization has occurred.

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
| `TPCDS_DEBUG` | `1` | Phase 1 bootstrap and pipeline debugging | `D3_CONTRACT_FROZEN`; derivation not started; `debug_store_sales_row_limit = 500000` |
| `TPCDS_SF1` | `1` | Initial scale-factor-1 controlled dataset for later benchmark coverage | `D2_HUMAN_APPROVED`; canonical immutable raw generation exists; materialization not started |

`TPCDS_SF1` means this project's selected-table materialization derived from a reviewed `dsdgen` scale-factor-1 generation. It does not imply that the project materializes or executes the complete official TPC-DS database or query suite.

`TPCDS_DEBUG` is a distinct debug dataset identity. It is not a fractional-scale
`dsdgen` invocation. It is a deterministic, relationship-closed reduction of one
exact verified `TPCDS_SF1` version 1 raw generation, as frozen in Section 5.

The serialized provenance value for both initial dataset versions is
`TPCDS_BASED_CONTROLLED_BENCHMARK_SYNTHETIC`. Every manifest must also record
`production_data = false` and `official_tpc_benchmark_result = false`.

Planned size is never substituted for measured size. The canonical SF1 raw
generation has observed counts recorded in its terminal manifest: 25 files,
1,253,309,714 bytes, and 19,557,376 physical records. Debug-derived counts and
bytes remain unavailable until D4; Parquet bytes, files, and partitions remain
unavailable until materialization. Each value is recorded only as observed
metadata at its applicable stage.

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

## 4. Frozen `TPCDS_SF1` Generation Contract

### 4.1 Pinned toolkit input

The canonical D1 generator input is P04B Build A:

| Field | Frozen value |
|---|---|
| `toolkit_build_id` | `tpcds-tools-4.0.0-d63e2bf093e2-5436771f2f99-20260828T022901Z` |
| build manifest | `artifacts/tpcds_toolkit/tpcds-tools-4.0.0-d63e2bf093e2-5436771f2f99-20260828T022901Z/build_manifest.json` |
| platform | `linux/amd64` |
| runtime image identity | local content-addressed image ID `sha256:5436771f2f991b628573da053c84d553d5e24249a6b14c1f00a8db9d96d2007e` |
| `dsdgen` | `bin/dsdgen`; 539,776 bytes; SHA-256 `abfb87f7f9af017474969519dafa9fed34e61808d57114d6c7eee7f57549221f` |
| `tpcds.idx` | `share/tpcds/tpcds.idx`; 640,585 bytes; SHA-256 `19c11f3bc9745b342346ae3f5982f9fac33f8dcf0dd88f71db86f737489a2e5a` |
| source manifest SHA-256 | `fc4ce972cbe5dfee624592ec786585c5cf58f936d15a47067b3f6c15cdb63a2e` |

P04B Build B is repeat-build evidence, not an interchangeable fallback. No other
toolkit, rebuilt binary, or source modification may be substituted silently.

### 4.2 Exact invocation template

D2 must mount the pinned Build A artifact read-only at `/toolkit`, mount a new
empty Docker-managed Linux volume at `/output`, override the builder image's
build entry point, and invoke `dsdgen` as an argument vector rather than through
shell interpolation. The repository attempt's `raw/` directory is the final
local artifact target and is not the generator's Windows-backed output mount:

```text
/toolkit/bin/dsdgen
  -SCALE 1
  -RNGSEED 19620718
  -DIR /output
  -TABLE ALL
  -DELIMITER |
  -SUFFIX .dat
  -DISTRIBUTIONS /toolkit/share/tpcds/tpcds.idx
  -TERMINATE Y
  -FORCE N
  -QUIET N
  -CHILD 1
```

The display form must quote the delimiter as `'|'`; the actual argv element is
the one-byte string `|`. The execution working directory is the empty scratch
directory `/work`, not the source, build, toolkit, output, Spark, or YARN tree.
Both `DIR` and `DISTRIBUTIONS` are absolute, so the reviewed source has no data
resolution dependency on the current directory.

The exact environment is `LANG=C`, `LC_ALL=C`, and `TZ=UTC`. Network access is
disabled and the container root filesystem and `/toolkit` mount are read-only;
only unique Docker-managed Linux volumes mounted at `/work` and `/output` are
writable by the generator. The manifest records the actual process user, umask,
runtime/image identity, volume identities, and complete allowlisted environment.
No additional generator-specific environment variable is required: `dist.c`
opens the CLI `DISTRIBUTIONS` value directly.

#### 4.2.1 Approved D2 storage orchestration amendment

On `2026-08-29`, after the first D2 attempt became `PARTIAL`, the Human Tech Lead
approved a storage-only correction. The first attempt
`tpcds_sf1-v1-20260828T045222383Z-76d08a2ed9484671adfc1e48eac911fd`
must remain immutable. Its `/output` was a Docker Desktop `9p` bind mount backed
by host `E:` NTFS. Source inspection and live diagnostics observed that upstream
`print_end()` calls `fflush()` for every record; the process consequently waited
in `p9_client_rpc` for almost every small write. The Docker API later returned
`unexpected EOF`, leaving 18 of 25 files and no observable exit code.

The approved corrected lifecycle is:

1. create a new generation ID, empty repository `raw/` target, and unique empty
   Docker-managed Linux volumes for `/output` and `/work`;
2. run the unchanged direct `dsdgen` argv, environment, image, and Build A once;
3. require exit code zero and validate the expected 25 files, sizes, SHA-256
   values, physical-record counts, CR count, and final `|` + LF termination from
   a read-only Linux-side view of the staging volume;
4. copy the complete output set in one bounded bulk operation from the stopped
   generator container to the still-empty repository `raw/` directory;
5. independently hash and inspect the repository copies and require filename,
   byte-size, SHA-256, record-count, and termination equality with the Linux-side
   evidence; and
6. finalize `VERIFIED` only after all comparisons pass. Until then, the attempt
   is `IN_PROGRESS`; any output plus failed generation, validation, transfer, or
   comparison produces `PARTIAL` and stops without automatic retry.

The Docker volume/container identities, generation runtime, Linux validation
runtime, transfer runtime, post-copy verification runtime, and pre/post-copy
comparison result are mandatory manifest evidence. Staging resources are retained
through verification; their later deletion is a separate cleanup decision. This
amendment changes storage transport only. It does not change `DIR=/output`, output
bytes or record semantics, Build A, argv, environment, seed, table scope, or
parallel behavior. Any proposed change to those values still requires a new
Human-reviewed generation contract.

### 4.3 Effective parameter semantics

| Parameter | Frozen value / state | Source-grounded meaning |
|---|---|---|
| `SCALE` | `1` | Integer scale factor passed explicitly. |
| `RNGSEED` | `19620718` | Passed explicitly; `init_rand()` derives the column streams from it. |
| `DIR` | `/output` | Absolute path to the unique empty Docker-managed Linux staging volume; verified bytes are later bulk-copied to the unique repository raw directory. |
| `TABLE` | `ALL` | One full base-generation traversal. |
| `DELIMITER` | `|` | One-byte field separator. |
| `SUFFIX` | `.dat` | Output suffix. |
| `DISTRIBUTIONS` | `/toolkit/share/tpcds/tpcds.idx` | Explicit absolute path to the pinned index. |
| `TERMINATE` | `Y` | Each record ends with the field delimiter before LF. |
| `FORCE` | `N` | Existing output is an error; overwrite is forbidden. |
| `QUIET` | `N` | Banner/errors are captured in logs. |
| `PARALLEL` | `DISABLED_BY_ABSENCE` | The option is deliberately omitted. Source validation rejects a supplied value below 2, so `-PARALLEL 1` is not a valid single-process spelling. |
| `CHILD` | `1` | Passed explicitly. With parallel disabled, the full row range is generated once and filenames have no chunk suffix. |

`ABREVIATION`, `PARAMS`, `UPDATE`, `VERBOSE`, `VALIDATE`, `_FILTER`, and
`CHKSEEDS` are unset. D2 may not add or abbreviate options or rely on a parameter
file. Any change to the argv, environment, runtime identity, table scope, seed,
or output semantics requires a new reviewed generation-contract version; it is
not a retry of this contract.

### 4.4 Full-table raw decision

D1 chooses **full standard raw generation**. The reviewed CLI accepts only one
`TABLE` string: one exact table name or `ALL`. In addition, `catalog_returns`,
`store_returns`, and `web_returns` are source-declared child tables that cannot
be requested independently and are emitted by their parent generators. A
selected six-table raw acquisition would therefore require multiple generator
processes and has non-obvious child-file side effects. Although the source uses
separate deterministic RNG streams, selected-run relationship equivalence to a
single `ALL` traversal has not been demonstrated by execution evidence. D1 does
not claim that selected generation is invalid; it declines to make an unverified
equivalence assumption.

The expected raw file set is exactly these 25 files:

```text
call_center.dat                 catalog_page.dat
catalog_returns.dat             catalog_sales.dat
customer.dat                    customer_address.dat
customer_demographics.dat       date_dim.dat
dbgen_version.dat               household_demographics.dat
income_band.dat                 inventory.dat
item.dat                        promotion.dat
reason.dat                      ship_mode.dat
store.dat                       store_returns.dat
store_sales.dat                 time_dim.dat
warehouse.dat                   web_page.dat
web_returns.dat                 web_sales.dat
web_site.dat
```

Any missing or additional raw file prevents `VERIFIED` status. Later
materialization remains limited to `store_sales`, `item`, `date_dim`, `customer`,
`customer_address`, and `store`; W03 initially needs only the first three. Full
raw generation does not expand the approved materialization or workload scope.

### 4.5 Repeatability

For each LF-terminated record, define:

```text
row_sha256 = SHA256(raw record bytes excluding the LF)
table_multiset_sha256 = SHA256(concatenate(sort_lexicographically(all 32-byte row_sha256 values)))
```

Duplicate rows remain duplicate digest entries. D2 repeat verification must
record the raw file SHA-256, physical-record count, and
`table_multiset_sha256`. For the 24 analytical table files (all expected files
except `dbgen_version.dat`), a repeated clean attempt is successful only when
the filename set, row counts, file byte sizes, raw file hashes, and multiset
hashes match. An order-independent content match with a byte-hash mismatch is an
anomaly requiring Human review, not an automatic pass.

`dbgen_version.c` records local generation date, time, version, and command line.
`TZ=UTC` pins time-zone interpretation but not wall-clock time. Preserve and hash
`dbgen_version.dat` exactly, validate its observed one-record structure and
version/command fields, and exclude only that file from cross-attempt byte and
multiset equality. Never normalize its timestamp in place.

## 5. Frozen `TPCDS_DEBUG` Version 1 Derivation

`TPCDS_DEBUG` version 1 is a deterministic derived-raw dataset, not a `dsdgen`
scale. Its sole allowed parent is one exact `VERIFIED` `TPCDS_SF1` version 1 raw
generation, referenced by terminal manifest path and SHA-256.

The sole canonical parent generation is
`tpcds_sf1-v1-20260829T111756030Z-7d5077c4df68486595486c875162e614`.
Its terminal manifest is
`artifacts/tpcds_raw/tpcds_sf1-v1-20260829T111756030Z-7d5077c4df68486595486c875162e614/generation_manifest.json`
with SHA-256
`e628a717c45ca66e7592c17a2a3006744c29fc17b2427ec1b19e4de9d1509620`.
The previous `PARTIAL` generation is non-canonical and may not be consumed.

The parameter `debug_store_sales_row_limit` is the Human-approved positive
integer `500000` for `TPCDS_DEBUG` version 1. There is no default, byte-size
target, percentage, or silent clamp. Changing this value requires a separately
reviewed dataset-contract/version decision. The algorithm below is frozen with
that value:

1. Verify the parent manifest and the recorded hashes for `store_sales.dat`,
   `item.dat`, and `date_dim.dat`. Read these files without modifying them.
2. Treat each LF-terminated `store_sales.dat` physical record as raw bytes before
   LF. Reject CR bytes, an unterminated final record, a record without the
   expected 23 values plus trailing `|`, or invalid key syntax under the pinned
   4.0.0 DDL field order.
3. For source line `L` with raw record bytes `R`, calculate
   `SHA256(ASCII("TPCDS_DEBUG/1/store_sales") || 0x00 || R)`. Rank rows by the
   unsigned lexicographic tuple `(digest, R, L)` and select the lowest
   `debug_store_sales_row_limit` rows. Fail if the requested limit exceeds the
   observed parent fact-row count; do not change the parameter.
4. Emit the selected `store_sales.dat` records in ascending original source-line
   order, preserving every selected record byte and its LF terminator.
5. From selected facts, obtain distinct non-null `ss_item_sk` (field 3) and
   `ss_sold_date_sk` (field 1). Empty `ss_item_sk` is invalid because the pinned
   DDL marks it non-null; empty `ss_sold_date_sk` is allowed and counted as a null
   reference.
6. Emit from the parent `item.dat` exactly the rows whose non-null field-1
   `i_item_sk` is referenced. Emit from `date_dim.dat` exactly the rows whose
   non-null field-1 `d_date_sk` is referenced. Preserve matching parent records
   and LF terminators in parent source order. No other dimension row is included.
7. Produce exactly `store_sales.dat`, `item.dat`, and `date_dim.dat`, plus the
   derivation manifest and logs. Expanding this scope requires a new dataset
   version or separately approved contract change.

Validation is fail-closed and records observed counts: selected fact rows;
distinct/non-null/null foreign keys; matched and missing keys; duplicate or
invalid dimension keys; extra derived dimension keys; malformed records; and
duplicate `(ss_item_sk, ss_ticket_number)` fact primary keys. Missing referenced
item/date keys, duplicate dimension primary keys, any extra derived dimension
row, or an invalid required key prevents `VERIFIED` status. Null sold-date keys
are reported but are not missing-key violations.

Two reductions are repeatable only when parent manifest/hash, row-limit value,
derivation-spec version, and reducer code revision match and all three output
filenames, row counts, byte sizes, SHA-256 values, multiset hashes, and validation
counts are identical. No derivation may rewrite or annotate the parent raw files.

## 6. Raw Generated and Derived Artifact Boundary

Raw generated or derived data is immutable evidence of a particular reviewed
generator build/invocation or deterministic parent/reduction contract.

The local-only repository-relative layout is:

```text
artifacts/tpcds_raw/
  <generation_id>/
    generation_manifest.json
    generation_manifest.sha256
    logs/
      stdout.log
      stderr.log
    raw/
      <frozen output files>
```

`generation_id` has the form
`<dataset-id-lower>-v<dataset-version>-<UTC-yyyyMMddTHHmmssfffZ>-<uuid>`. The
resolved attempt root must not exist before D2 creates it. D2 must first add and
verify the narrow Git ignore boundary `artifacts/tpcds_raw/`; D1 creates neither
the ignore entry nor the directory. Every existing path component is resolved
and checked against repository/workspace escape and symlinks. `raw/` must be a
new empty directory.

The manifest schema must include at least:

- schema/spec version, generation ID, dataset ID/version, provenance fields, and
  operation kind (`DSDGEN_GENERATION` or `DETERMINISTIC_REDUCTION`);
- canonical toolkit build ID/manifest, archive/source references, runtime image
  identity, `dsdgen` size/SHA-256, and `tpcds.idx` size/SHA-256;
- exact argv array and display command, effective parameters including explicit
  disabled/not-applicable values, environment, process user/umask, working
  directory, mount/path mapping, and code revision plus dirty-state observation;
- Docker staging/output/work volume identities, Linux-side validation evidence,
  generation/validation/transfer/post-copy durations, and the bounded copy method;
- observed UTC start/end times, exit code/signal, lifecycle status, and captured
  stdout/stderr log references with sizes and SHA-256 values;
- expected and observed filename sets; for every file, repository-relative path,
  table name, byte size, SHA-256, safely measured physical-record count and
  method, and `table_multiset_sha256` where applicable;
- for a derivation, parent manifest/hash, parent file hashes, exact reduction
  parameter, algorithm/spec version, reducer code revision, and all relationship
  validation counts; and
- anomalies/errors and the terminal manifest sidecar SHA-256.

Lifecycle values are exactly `IN_PROGRESS`, `FAILED`, `PARTIAL`, and `VERIFIED`.
`FAILED` means the operation failed with no raw table output; `PARTIAL` means any
raw output exists but the command/derivation or verification did not complete
successfully. `VERIFIED` requires successful exit plus every frozen integrity,
filename, record, repeatability, and relationship check applicable to the
operation. `IN_PROGRESS` is non-terminal and must not be consumed.

- Store each generation or derivation under a unique, versioned artifact reference.
- Resolve a new empty output directory outside the vendored source/build tree; reject symlink/path escape and any non-empty/existing artifact target.
- Never overwrite a verified raw generation.
- Do not use `FORCE` to overwrite verified or partial generation artifacts.
- Preserve exact file hashes and the generator/derivation logs and manifest.
- Keep failed or partial generations separate and mark their status explicitly.
- Do not silently repair, sample, cast, or normalize raw generator output in place.
- Never invoke the toolkit's upstream tests or cleanup scripts as part of generation.
- Do not treat raw generator output as Spark/YARN execution evidence; Spark/YARN evidence remains governed by `raw_data_contract.md`.

Before terminal status, an interrupted attempt is finalized as `FAILED` or
`PARTIAL` without deleting output. Terminal artifacts are read-only/immutable and
must never be promoted over another identity. There is no automatic retry. A
retry creates a new generation ID with the identical approved contract; any
parameter change is recorded as a new, separately reviewed contract. No fallback
toolkit, source edit, upstream cleanup/test target, or `FORCE` overwrite is
allowed. Retention/deletion of any terminal attempt requires separate Human
authorization.

## 7. Controlled Materialization Contract

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

## 8. Dataset Manifest

Each verified materialization must record at least:

| Field | Meaning |
|---|---|
| `dataset_id` | `TPCDS_DEBUG` or `TPCDS_SF1` for the initial design |
| `dataset_version` | separate version value, initially `1` |
| `benchmark_provenance` | `TPCDS_BASED_CONTROLLED_BENCHMARK_SYNTHETIC`; also record `production_data = false` and `official_tpc_benchmark_result = false` |
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

## 9. Workload Input Accounting

Each experiment must reference the dataset manifest and list the exact table/path inputs actually read. `actual_input_size_bytes` is derived from the materialized inputs selected by that workload only when it is genuinely available before submission and its derivation is documented.

Toolkit version, generator parameters, dataset identity, and materialization settings are lineage metadata. They are not automatically eligible model features. Feature eligibility and same-run leakage rules remain governed by `feature_schema.md`.

## 10. Known Limitations and Open Decisions

- D1 and the storage-only D2 orchestration correction are Human-approved. The
  first D2 generation is terminal `PARTIAL`; it is not a dataset and may not be
  consumed, promoted, retried in place, or used for debug calibration.
- Corrected generation
  `tpcds_sf1-v1-20260829T111756030Z-7d5077c4df68486595486c875162e614`
  completed the approved Linux-volume lifecycle and is locally `VERIFIED` with
  25/25 raw files, exact Linux/repository identity, and matching raw and row-
  multiset hashes for all 24 analytical tables in an independent clean repeat.
  The Human approved Review Gate D2 on `2026-08-29`; this is the canonical
  `TPCDS_SF1` version 1 raw generation.
- D3 freezes `debug_store_sales_row_limit = 500000` for `TPCDS_DEBUG` version 1.
  D4 derivation remains separately gated and has not started.
- No Parquet materialization, HDFS publication, `TPCDS_DEBUG` derivation, or
  Spark/YARN workload execution has begun.
- Initial workload coverage does not guarantee a controlled skew case; skew must be profiled from observed data/executions and never asserted from the workload name.
- Toolkit licensing/direct-control evidence, public redistribution compliance,
  and any future packaging remain Human/Legal review items as described in
  `tpcds_implementation_plan.md`.
