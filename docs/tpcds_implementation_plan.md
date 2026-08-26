# TPC-DS Benchmark Foundation — Future Implementation Plan

## 1. Scope and Stop Boundary

This is a future implementation plan only. P01 and the P03 environment-status transition authorize no toolkit cleanup, build, data generation, materialization, workload implementation, Spark submission, `C1` resolution, or `EXP_001` execution.

The plan migrates only the benchmark data/workload foundation. It does not redesign Spark-on-YARN infrastructure, collection, the execution-level data model, feature availability/leakage rules, ML formulation, evaluation, optimization, or recommendation policy.

Each step below has an independent human review gate. Passing one gate does not approve later steps or any existing Research Gate.

## 2. Read-Only Toolkit Inventory

The repository currently contains:

```text
B0CF2ADA-2F20-4296-A89C-81B8202DCD13-TPC-DS-Tool/
  DSGen-software-code-4.0.0/
  __MACOSX/
```

Observed without building or running it:

- the source identifies TPC-DS DSGen version `4.0.0` through the directory/specification names and `tools/release.h`;
- build targets include `dsdgen`, `dsqgen`, `distcomp`, `mkheader`, and `checksum`;
- the payload contains C sources, distribution files, DDL/RI SQL, query templates/variants, answer sets, upstream tests, and the TPC-DS 4.0.0 specification PDF;
- the selected six tables and five initial relationships appear in the committed DDL/RI material;
- generator source exposes controls including output directory, integer scale, table selection, parallel/child generation, RNG seed, delimiter, and suffix; source defaults indicate pipe-delimited `.dat` output and RNG seed `19620718`, but future automation must set and record all effective values explicitly;
- the source marks scale factor 1 as a qualification scale; selected-table-only and parallel-generation relationship behavior has not been verified;
- no generated `.dat`/CSV/Parquet data and no compiled `dsdgen`, object, shared-library, Java, or Windows executable artifacts were observed;
- all 1,145 files are tracked; their current Windows worktree representations
  total 12,014,790 bytes, while the portable committed-source identity is the
  Git tree object recorded below and Git blob byte totals may differ because of
  line-ending normalization;
- `__MACOSX` contributes 576 files and 3,180,455 bytes, primarily AppleDouble metadata plus a duplicate specification PDF;
- the toolkit first appears in repository commit `ac2b36989fb58ae7597cfe30da1c15bf931a9fdf`;
- the current toolkit Git tree object is `749d129d1a22e2828b0be787231904be7563a135`;
- no original download URL, acquisition date, archive checksum/signature, or provenance manifest was found.

These observations identify the committed bytes; they do not establish upstream authenticity or a reproducible build.

### Repository hygiene concerns

- The GUID-style top-level directory is opaque and the toolkit is not under an explicit third-party/vendor boundary.
- `__MACOSX`, AppleDouble files, `.DS_Store`, and a duplicate specification PDF add unrelated archive metadata.
- Shell scripts are committed with non-executable Git modes.
- Build toolchain versions are not pinned.
- Upstream tests contain hard-coded paths and potentially destructive database/filesystem commands; they must remain inert until isolated and reviewed.
- No project-owned provenance/third-party notice connects the committed tree to an official archive.

P01 deliberately does not clean, move, delete, or modify any of these files.

## 3. Licensing and Result-Disclosure Considerations

The committed `EULA.txt` identifies EULA version `2.2` and states that the materials are licensed rather than sold. Its redistribution conditions include retaining notices, including the complete EULA, applying a specified prominent all-caps legend, and not charging a distribution fee. It also addresses export control and public performance disclosure. It permits academic/research disclosure under stated conditions and otherwise requires non-authorized results to be identified as not comparable to TPC Benchmark Results.

This inventory is not legal advice. A human/legal review must decide whether continued public GitHub distribution and any future source, binary, or container packaging comply with the EULA. Until that review:

- preserve the EULA and all notices;
- do not redistribute a derived toolkit/binary/container as a project deliverable;
- describe the project only as a **TPC-DS-based controlled benchmark** using **TPC-DS-derived analytical workloads**;
- state that project results are not comparable to official TPC Benchmark Results;
- do not publish official TPC-DS metrics or claim official compliance.

## 4. Future Integration Options

### Option A — Use the current vendored source through an isolated build wrapper

Pin the Git tree, compiler/`lex`/`yacc` versions, build command, build environment/image, resulting binary hash, generated `tpcds.idx` hash, and every other required runtime artifact. Invoke only explicitly reviewed `dsdgen` paths.

Trade-off: strongest offline continuity with the current repository, but provenance and repository-hygiene gaps remain and licensing review is mandatory.

### Option B — Retrieve a pinned official upstream archive

Record the authoritative URL, version, acquisition date, archive hash/signature where available, license acceptance, and a verified extraction manifest.

Trade-off: clearer upstream provenance and a cleaner repository, but adds network/artifact-availability and license-acceptance dependencies.

### Option C — Use a reproducibly built binary/container artifact

Pin source, toolchain, build recipe, image digest, target architecture, and binary hash; store or retrieve the artifact only under an approved licensing/distribution process.

Trade-off: repeatable execution environment, but highest packaging and redistribution-review burden.

P01 does not select an option. The Human Tech Lead must approve one before build work starts.

## 5. Small-Step Implementation Sequence

### Step 1 — Toolkit Provenance, License, and Hygiene Decision

Documentation/review only:

1. confirm the authorized upstream source and acquisition history;
2. review EULA/public-repository and artifact-distribution obligations;
3. choose one integration option;
4. decide whether repository cleanup/vendor relocation is authorized;
5. record the decision and immutable provenance identifiers.

**Review Gate T1:** Human approval of provenance, licensing disposition, integration option, and any repository mutation. No build before T1.

### Step 2 — Reproducible Build Contract

Define without compiling:

1. pin build OS/architecture and compiler/`lex`/`yacc` versions;
2. create an isolated build path that cannot invoke upstream tests implicitly;
3. define the exact build command and the required source/log manifest, binary hash, generated `tpcds.idx`/runtime-artifact hashes, and effective `DISTRIBUTIONS` path;
4. define bounded static/smoke checks that generate no benchmark dataset;
5. scope the future infrastructure-only smoke/observability negative-boundary assertions so those artifacts cannot be mislabeled with any new benchmark dataset/workload identifier, without rejecting legitimate future benchmark artifacts or changing infrastructure behavior.

**Review Gate T2:** Human approval of the exact isolated build contract. No compilation before T2.

### Step 3 — Isolated Build Integration and Evidence

Implement only the T2-approved build path, keep upstream tests inert, verify the binary-reported version, run only the approved no-data checks, and capture every required runtime-artifact digest.

**Review Gate T3:** Reproducible build evidence and runtime artifact identities accepted. T3 does not authorize data generation.

### Step 4 — Dataset Definition Contract

Documentation/configuration only at first:

1. freeze exact `TPCDS_SF1` version `1` generation parameters;
2. define a deterministic, relationship-safe `TPCDS_DEBUG` version `1` derivation without assuming fractional scale;
3. decide full-table versus selected-table raw generation;
4. define raw artifact identity, status, retention, and checksum fields;
5. define failure/partial-output handling.
6. define repeatability for the approved analytical tables separately from generator metadata such as `dbgen_version` date/time/command fields; pin relevant time zone/environment inputs and preserve raw metadata unchanged.

**Review Gate D1:** Human approval of both dataset definitions and generator invocations. No generation before D1.

### Step 5 — Raw Generation Integration

Implement only the reviewed generator wrapper:

1. run with explicit effective parameters (including `DISTRIBUTIONS`, `TERMINATE`, `FORCE`, and `QUIET`), pinned runtime artifacts, and bounded resources;
2. preserve logs and raw outputs immutably;
3. calculate hashes and write the generation manifest;
4. test reviewed table/content repeatability on the approved debug path while separately preserving/reporting non-deterministic generator metadata;
5. retain failures/partial outputs with explicit status.
6. use a resolved unique empty output directory outside the vendored source/build tree; reject symlink/path escape, refuse overwrite/`FORCE` against any verified or partial artifact, and never invoke upstream tests or cleanup scripts.

**Review Gate D2:** Raw debug generation integrity and reproducibility accepted. D2 does not authorize Parquet materialization or Spark workloads.

### Step 6 — Materialization Contract

Define schemas, null/decimal/date mappings, selected tables, relationship checks, partition policy, HDFS paths, overwrite prevention, and manifest serialization without writing materialization code or data.

**Review Gate M1:** Human approval of the complete raw-to-Parquet/Snappy materialization contract. No materialization implementation before M1.

### Step 7 — Materialization Implementation and Evidence

Implement only the M1-approved contract, then perform bounded `TPCDS_DEBUG` materialization and read-back verification under separate authorization.

**Review Gate M2:** Observed schemas, counts, sizes, files, hashes, and relationship-check results for `TPCDS_DEBUG` accepted. No workload implementation before M2.

### Step 8 — Workload Contracts

Freeze exact transformations, predicates, join semantics, aggregate formulas, actions, output checks, and controlled Spark settings for each workload. Review `W03_TPCDS_JOIN` first because it is the bootstrap dependency. Do not represent project SQL as an official TPC-DS query unless an explicit reviewed mapping supports that statement.

**Review Gate W1:** The exact `W03_TPCDS_JOIN`, workload-version-1 contract is semantically approved. W1 does not authorize implementation or Spark execution.

**Review Gate W3:** The remaining five workload-version-1 contracts are approved. W3 may occur after the bootstrap and does not block Phase 1.

### Step 9 — Workload Implementation and Verification

Implement and statically/unit-test each workload only after its contract gate. Verification must check logical output correctness independently of performance and must not fabricate Spark/YARN outcomes.

**Review Gate W2:** Implementation/test evidence for `W03_TPCDS_JOIN`, workload version `1`, is accepted. W2 does not authorize `EXP_001`.

**Review Gate W4:** Implementation/test evidence for the other five workload-version-1 definitions is accepted. W4 may occur after the bootstrap and does not block Phase 1.

### Step 10 — Bootstrap Readiness

Independent prerequisites:

- `LOCAL_YARN_V1` is human-reviewed and marked `VERIFIED` — satisfied on 2026-08-25 by verification session `LOCAL_YARN_V1_20260824T073936243Z_7cb92321` and snapshot `LOCAL_YARN_V1_SNAPSHOT_20260824T074804856Z_de925815`;
- `C1` is resolved and approved against that verified environment;
- T1, T2, T3, D1, D2, M1, M2, W1, and W2 have passed;
- collectors/raw contracts required for the trace are ready;
- a `PLANNED` `EXP_001` record binds the exact environment snapshot, dataset manifest, workload version, code revision, and configuration.

**Review Gate B1:** Human authorization of the exact `EXP_001` specification. B1 is the only gate in this plan that may authorize later Spark submission; neither P01 nor P03 grants it.

### Step 11 — Execute and Collect `EXP_001`

Under a separate task after B1:

```text
EXP_001
  -> LOCAL_YARN_V1
  -> TPCDS_DEBUG / dataset_version 1
  -> W03_TPCDS_JOIN / workload_version 1
  -> C1
  -> observed spark_application_id
  -> immutable Spark History/event-log and YARN evidence
```

Inspect outputs, preserve negative/anomalous results, and request human Data Gate review. Do not continue automatically into systematic Phase 3 runs.

## 6. Relationship to Research Gates

T1–T3, D1/D2, M1/M2, W1–W4, and B1 are implementation review gates, not replacements for the Data, Feature, Dataset, Baseline, Model, Recommendation, or Validation Gates. The agent may not self-approve any of them.

## 7. Open Decisions

- toolkit integration option and licensing disposition;
- authorized provenance for the committed source;
- whether/how the vendored tree may be cleaned or relocated;
- exact `TPCDS_DEBUG` derivation;
- raw generation table scope and parameters;
- materialization schemas, partitioning, HDFS paths, and correctness rules;
- exact SQL/action/check contracts for all six workloads;
- controlled skew coverage after profiling;
- `C1`, still **TBD**; the environment-verification prerequisite is satisfied, but a separate conservative `C1` review and Human approval remain required.
