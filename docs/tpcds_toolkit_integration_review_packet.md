# TPC-DS Toolkit Integration Review

- Task: `P04A` — TPC-DS Toolkit Integration Review Gate
- Review date: `2026-08-26`
- Human decision date: `2026-08-27`
- Repository revision reviewed: `e174cbdea01806f5df51ad570e207d02743d3eb9`
- Review status: **HUMAN APPROVED**
- Selected strategy: **Option B — external/pinned upstream acquisition**
- Active-tree disposition: **REMOVE THE PREVIOUSLY EXTRACTED TOOLKIT**; preserve existing Git history and perform no history rewrite
- P04B contract status: **FROZEN / IMPLEMENTATION NOT_STARTED**

This packet began as decision support. It now also records the Human Tech Lead's
Option B decision, approved active-tree cleanup, and frozen P04B build contract.
It preserves the planning contracts in
[ADR-0004](adr/ADR-0004-adopt-tpc-ds-as-controlled-benchmark-foundation.md)
and the [TPC-DS implementation plan](tpcds_implementation_plan.md). No toolkit was
extracted, built, or executed by this decision task, and no benchmark data was
generated.

## 1. Current state

- TPC-DS remains `PLANNED / NOT_STARTED`; toolkit build and dataset generation are
  `NOT_STARTED`; the Data Gate remains `NOT_APPROVED`.
- The Human approved Option B on `2026-08-27` and authorized removal of the
  previously extracted third-party toolkit tree at
  `B0CF2ADA-2F20-4296-A89C-81B8202DCD13-TPC-DS-Tool/` from the active tree.
- The old toolkit remains in existing Git history. No history rewrite is authorized.
- The canonical future P04B input is the local, ignored, untracked archive
  `.local/tpcds/BBC82A1E-AE00-4C0B-9255-EBAF6CA0972B-TPC-DS-Tool.zip`, observed as
  `7,479,651` bytes with locally calculated SHA-256
  `d63e2bf093e23964b393364991be9fdd7a9cdd40fcdf91f99660eabde4c6162d`.
  This digest is not a publisher-authenticated checksum.
- Project-owned benchmark generation, dataset, workload, and experiment directories
  contain placeholders only. No TPC-DS integration code exists.
- No compiled generator, `tpcds.idx`, generated `.dat`, Parquet dataset, or
  implemented TPC-DS Spark workload was found.
- Before the approved cleanup, the entire old toolkit was tracked in Git. It was
  neither a submodule nor a Git LFS object and had no explicit `third_party` or
  `vendor` boundary.

The historical tree must not be used as a P04B source or fallback. Option B does
not authenticate the historical committed bytes, and the legal/governance
limitations below remain unresolved.

## 2. Historical toolkit inventory

### 2.1 Identity and contents

The following inventory describes the P04A-reviewed Git tree that is now
intentionally removed from the active tree. It remains historical Git evidence,
not canonical Option B input.

| Item | Observed evidence |
|---|---|
| Apparent package | TPC-DS DSGen software/source payload |
| Apparent version | `4.0.0`; directory/specification names and `tools/release.h` macros agree |
| Toolkit Git tree | `749d129d1a22e2828b0be787231904be7563a135` |
| Primary source subtree | `afb45000d12a44d4f2069f4b0acf864ef6b89256` |
| Tracked inventory | 1,145 files; all Git mode `100644`; 11,952,689 Git path-entry bytes |
| Windows worktree inventory | 12,014,790 bytes |
| Main payload | 569 files / 8,834,335 worktree bytes |
| macOS metadata payload | 576 files / 3,180,455 worktree bytes |

Important main-payload directories are:

- `tools/`: C source, distributions, DDL/RI SQL, build files, and legacy platform files;
- `query_templates/` and `query_variants/`: upstream query material;
- `answer_sets/`: upstream answer/reference outputs;
- `tests/`: legacy shell and SQL tests;
- `specification/`: the TPC-DS 4.0.0 specification PDF;
- `EULA.txt`: TPC EULA version 2.2.

The payload contains material owned or attributed to TPC, Gradient Systems, and
other third parties noted in section 4. It is third-party material, not project
source.

### 2.2 Build system and expected targets

The identical `tools/makefile` and `tools/Makefile.suite` use GNU-style Make and
default to Linux, `gcc`, `lex`, and `yacc`. The declared program targets are:

- `dsdgen` — data generator;
- `dsqgen` — query generator;
- `distcomp` — distribution compiler;
- `mkheader` — generated-header helper;
- `checksum` — checksum helper.

The default `all` target also produces `tpcds.idx`. Its dependency graph writes
objects, generated headers, `tpcds.idx.h`, binaries, and `.ctags_updated` into the
source directory. A Visual Studio 2005 Win32 solution and `.vcproj` files are also
bundled, but they are legacy, have inconsistent historical naming, and have not
been verified with a current Windows compiler.

## 3. Provenance findings

### 3.1 Observed

- The apparent toolkit and bundled specification versions are both 4.0.0.
- The bundled EULA identifies itself as version 2.2.
- Git introduced all 1,145 toolkit files in commit
  `ac2b36989fb58ae7597cfe30da1c15bf931a9fdf`, authored and committed under the
  name `AnhTaizz` on `2026-08-24T15:18:13+07:00`.
- That commit is unsigned, has no Git note, and its message describes Spark-on-YARN
  infrastructure rather than a toolkit acquisition/import.
- The toolkit tree is unchanged between that commit and the reviewed revision.
- On `2026-08-26`, the [TPC current specifications page](https://www.tpc.org/TPC_Documents_Current_Versions/current_specifications5.asp)
  listed TPC-DS 4.0.0 and named the current package
  `TPC-DS_Tools_v4.0.0.zip`. The [official download request page](https://www.tpc.org/TPC_Documents_Current_Versions/download_programs/tools-download-request5.asp?bm_type=TPC-DS)
  required registration and explicit EULA agreement before issuing a temporary
  download link.

The current TPC pages are discovery evidence only. They do not connect the
committed bytes to an original download.

### 3.2 Missing or unknown

| Provenance field | Finding |
|---|---|
| Original download URL or temporary link | **MISSING / UNKNOWN** |
| Download/acquisition date | **MISSING / UNKNOWN**; the Git import date is not a download date |
| Original archive filename | **MISSING / UNKNOWN**; the currently advertised filename is not proof of the imported archive |
| Original archive size and checksum | **MISSING / UNKNOWN** |
| Upstream signature, signer, or other independent integrity evidence | **MISSING / UNKNOWN** |
| Extraction/source manifest | **MISSING / UNKNOWN** |
| Person who downloaded and accepted the EULA | **MISSING / UNKNOWN**; Git identifies a committer only |
| Import procedure and authorization | **MISSING / UNKNOWN** |
| Licensee identity, organizational contact, and acceptance record | **MISSING / UNKNOWN** |

The bundled `tools/tpcds_20080910.sum` refers to historical `/data/*.dat`
outputs. It is not an archive checksum and is not current project evidence.

## 4. Licensing and EULA findings

This section reports repository evidence; it is not legal advice.

| Issue | Evidence and disposition |
|---|---|
| Acceptance | `EULA.txt:5` states that installing or using the materials constitutes acceptance and addresses organizational authority. No acceptance record exists. Whether compiling is covered and who may accept is **HUMAN / LEGAL REVIEW REQUIRED**. |
| Direct control and organizational use | `EULA.txt:23-25` limits use to systems under the user's direct control and defines individual/organizational access, including an organization contact. Hosted CI applicability is **HUMAN / LEGAL REVIEW REQUIRED**. |
| Redistribution | `EULA.txt:39-43` permits limited redistribution subject to the complete EULA, a prescribed prominent all-caps legend, preserved notices, and no distribution fee. The EULA is present, but the required legend was found only inside the clause, not as a project-owned top-level notice. Public GitHub compliance is **HUMAN / LEGAL REVIEW REQUIRED**. |
| Modification and notices | `EULA.txt:30,35-38` permits software modification while restricting license/notice removal and retaining terms on integrated portions. Any cleanup, subset, wrapper, or relocation disposition is **HUMAN / LEGAL REVIEW REQUIRED**. |
| Result disclosure | `EULA.txt:31-34` allows stated academic/research disclosure and otherwise requires non-authorized results to be identified as not comparable to TPC Benchmark Results. Existing project terminology is directionally consistent but does not establish permission. |
| Export | `EULA.txt:7,57` contains export-control obligations. Public hosting and international access are **HUMAN / LEGAL REVIEW REQUIRED**. |
| Specification usage | The bundled specification's Appendix F contains an unresolved editorial placeholder and says the electronic material is intended for TPC-DS benchmark execution, with other use requiring prior consent. Its relationship to the EULA's academic/research language is **HUMAN / LEGAL REVIEW REQUIRED**. |
| Embedded Gradient notice | `tools/tokenizer.c:405-426` contains conflict markers and a separate proprietary/confidential Gradient Systems notice, while `tokenizer.l` carries the general TPC notice. Authority to distribute or compile this file is **HUMAN / LEGAL REVIEW REQUIRED**. |
| Other embedded material | `tools/y.tab.c` identifies a FreeBSD yacc skeleton without a separate bundled license, and two answer sets include Oracle SQL*Plus copyright banners. Their redistribution status is **HUMAN / LEGAL REVIEW REQUIRED**. |
| Binary/container packaging | The EULA definition includes executables and modified software. Registry, release, CI-cache, binary, or container distribution is **HUMAN / LEGAL REVIEW REQUIRED**. |

Until these questions are resolved, do not publish a toolkit-derived binary or
container, automate acceptance, or represent continued public vendoring as
compliant.

## 5. Repository hygiene findings

- The GUID-like top-level directory is opaque and unexplained.
- `__MACOSX` contains 575 AppleDouble `._*` files plus a byte-identical duplicate
  of the 3,078,797-byte specification PDF. The main payload also contains
  `.DS_Store`.
- All files are mode `100644`, including 20 real shell scripts. Line-ending rules
  cover shell scripts but not all toolkit text, so future byte identities must use
  archive/Git bytes rather than platform-converted worktree bytes.
- The two makefiles are byte-identical.
- No compiled or generated artifacts are currently present.
- Existing ignore rules do not cover representative toolkit binaries, objects,
  `tpcds.idx`, generated `.dat`, Parquet, or TPC-DS build/log paths.
- Broad upstream targets are unsafe for project automation: `release` performs
  source/update/archive/test work; `data_set` deletes `/data/*.dat` and generates
  data; `clean` can delete tracked generated parser/tokenizer sources.
- Legacy tests can delete `/data/*.csv`, drop/recreate databases, use fixed example
  credentials, and reference `/tmp`, `/data`, `~jms`, and hard-coded Windows paths.
  The test harness also contains missing/wrong-case script references.

P04A itself performed no cleanup. On `2026-08-27`, the Human subsequently
approved removing this extracted tree from the active repository tree. The
cleanup does not rewrite or remove the toolkit from existing Git history.

## 6. Build and reproducibility gaps observed by P04A

At the original P04A review, the repository had no approved project-owned
contract for the areas below. Section 14 now freezes the P04B control boundary.
Values that can only be selected or observed during P04B remain explicitly TBD
and must fail closed until resolved.

| Area | Current gap |
|---|---|
| Acquisition | No trusted archive record, checksum validation, or acceptance workflow |
| Toolchain | No pinned compiler, Make, libc, platform/architecture, or auxiliary-tool versions |
| Build isolation | Upstream Make writes into source; no immutable/read-only input or isolated output root |
| Wrapper | No allowlisted build target/command and no protection from unsafe upstream targets/tests |
| Build environment | No dedicated image or digest; the existing `LOCAL_YARN_V1` image is not a toolkit build contract |
| Binary contract | No canonical platform, filename, path, size, hash, or build ID |
| Runtime support | No `tpcds.idx` path, pairing, hash, or effective `DISTRIBUTIONS` contract |
| Version validation | Source macros are observed, but no binary-reported version is verified |
| Evidence | No resolved command, toolchain snapshot, source manifest, build log, or status manifest |
| Failure handling | No unique build directory, partial-output quarantine, or promotion rule |
| Verification | No bounded no-data identity/smoke command or repeat-build comparison |
| Git safety | No scoped ignores for acquisition cache, build outputs, generator outputs, or materialized data |

The existing Docker builder installs `build-essential` for other infrastructure
work but does not include the toolkit, pin the TPC-DS toolchain, or provide
`lex`/`yacc`/`ctags`. It must not be treated as an implicit toolkit strategy, and
`LOCAL_YARN_V1` must not be modified by this integration.

## 7. Option A — keep vendored source

**Assessment:** technically simple and strong for offline replay, but currently
not safe to approve.

- Reproducibility can be strong after authenticating the source and pinning the
  Git subtree plus an isolated toolchain.
- Offline development and CI checkout are simple if redistribution and hosted-CI
  use are legally approved.
- The current repository already bears source/noise/history cost, and in-place
  builds create divergence and accidental-commit risk.
- Provenance cannot be repaired by a Git tree hash alone; the committed tree must
  first be compared with an authorized upstream acquisition or other authoritative
  evidence.
- Cleanup, relocation, notice treatment, and updates require explicit review.
- Public-source redistribution and embedded-notice questions remain the largest
  risk.

## 8. Option B — external/pinned upstream acquisition

**Assessment:** best fit for this repository, subject to Human/Legal approval.

- A Human obtains the approved 4.0.0 archive through the official acceptance flow;
  project automation never clicks through or claims acceptance.
- A version-controlled lock/provenance record pins archive filename, size,
  SHA-256, acquisition evidence, extracted-tree manifest, EULA/spec identities,
  and the build contract.
- The archive and extracted source remain outside Git; a local, isolated,
  pinned Linux build environment produces ignored runtime artifacts.
- This yields cleaner provenance than the current unexplained extraction and
  reduces ongoing public redistribution exposure.
- Initial onboarding requires network access, registration, and Human action.
  The official page does not provide reviewed publisher checksum/signature
  evidence, so the recorded checksum protects continuity after acquisition but
  is not an independent publisher signature.
- Hosted CI is not automatic: it requires a compliant, access-controlled archive
  cache or is limited initially to local verification.
- Historical replay requires approved retention of the exact archive and lock
  record; a checksum without retained bytes is insufficient if upstream vanishes.

## 9. Option C — reproducible binary or container artifact

**Assessment:** technically strong but disproportionate for the current student
research scope.

- A pinned binary/container can make Windows use and CI execution convenient and
  can preserve an exact runtime environment.
- It still requires a complete source/acquisition/toolchain provenance chain.
- Publishing or sharing the binary/image creates the highest unresolved EULA,
  notice, export, registry, and CI-cache burden.
- Image storage, platform/architecture variants, base-image maintenance, registry
  retention, and security updates add operational cost.
- A private local-only image reduces distribution exposure but loses much of the
  option's collaboration/CI benefit.

## 10. Comparison matrix

Ratings are qualitative. `Strong` is favorable; for rows explicitly labeled
`risk` or `complexity`, `Lower` is favorable. Conditional ratings depend on the
controls described above.

| Criterion | Option A — vendored | Option B — pinned acquisition | Option C — artifact/container |
|---|---|---|---|
| Reproducibility | **Strong, conditional** on provenance repair | **Strong, conditional** on retained archive | **Strong** for a retained platform artifact |
| Licensing risk | **Higher / unresolved** public redistribution | **Lower / unresolved** user acquisition | **Highest / unresolved** artifact distribution |
| Provenance quality | **Weak now; moderate** after comparison | **Strongest** with recorded acquisition | **Strong** only with full source/build chain |
| Git repository cleanliness | **Weak** | **Strong** | **Strong** if artifact stays outside Git |
| Setup complexity | **Lower** after checkout | **Medium**; manual acquisition once | **Higher** |
| Windows friendliness | **Medium**; legacy native build, Docker preferred | **Strong** through local Docker build | **Strong** when a compatible image exists |
| Docker friendliness | **Strong** after wrapper work | **Strong** after wrapper work | **Strongest** operationally |
| CI friendliness | **Strong technically; legal pending** | **Weak initially**; compliant cache needed | **Strong technically; legal pending** |
| Offline usability | **Strong** | **Medium** after approved local retention | **Strong** after artifact retention |
| Long-term maintainability | **Medium**; vendor/update burden | **Strong** for one frozen release | **Weak to medium**; image/registry upkeep |
| Student-project complexity | **Low to medium** | **Medium** | **High** |
| Risk of accidental divergence | **Medium** unless source is immutable | **Low** with hash-before-extract | **Low** for pinned artifact; build drift still possible |
| Reproducing historical datasets | **Strong** after provenance repair | **Strong only if archive is retained** | **Strong only if artifact and source chain are retained** |

Option B's main weakness is acquisition/CI availability. It is still preferable
because that weakness can be managed with a single approved retained archive,
while Options A and C add unresolved public redistribution burdens.

## 11. Selected option — HUMAN APPROVED

The Human Tech Lead selected exactly **Option B — external/pinned upstream
acquisition** for AI-Driven Resource Tuning on `2026-08-27`.

This is the smallest reliable solution for the current local/research scope:

1. it creates a truthful acquisition record rather than retroactively treating an
   unexplained Git tree as upstream-authenticated;
2. it keeps the new local archive, future extracted source, binaries, and generated
   data out of future tracked history; the old extracted bytes remain in existing
   unchanged Git history;
3. it supports Windows development through a small, separate pinned Linux Docker
   build without changing `LOCAL_YARN_V1`;
4. it avoids the registry/artifact-management complexity of Option C;
5. it can reproduce historical data when the exact accepted archive, lock record,
   builder identity, `dsdgen`, and `tpcds.idx` are retained under an approved
   non-public artifact policy.

The canonical acquisition should be Human-mediated. The future wrapper should
accept a local archive path, verify it, and never download the toolkit or automate
EULA acceptance.

The Human also approved removal of the old extracted toolkit from the active tree
and explicitly did not authorize a history rewrite. This decision freezes the
P04B contract in section 14 but does not perform or prove a build and does not
authorize publishing toolkit-derived artifacts.

## 12. Unselected fallback option

Option A is not selected and P04B must not fall back to it. A future switch to
**Option A — keep vendored source** would require a new explicit Human decision
and all of the following:

- official 4.0.0 reacquisition becomes unavailable or the approved project must
  support offline/CI use that cannot be served by a compliant retained archive;
- Human/Legal review explicitly permits the intended public vendoring and use;
- the source is authenticated against an authorized upstream package or other
  authoritative evidence;
- all required EULA/third-party notices and the public-repository disposition are
  resolved; and
- the Human explicitly authorizes a vendor boundary, any cleanup/relocation, and
  an immutable isolated build process.

If any condition is unmet, stop. Do not switch automatically to Option C.

## 13. Required Human decisions

| ID | Decision required | Current state |
|---|---|---|
| `H1` | Select Option B, select the conditional fallback, or reject both | **APPROVED 2026-08-27 — OPTION B** |
| `H2` | Determine whether the non-official academic/research use is permitted given the EULA and specification Appendix F | **HUMAN / LEGAL REVIEW REQUIRED** |
| `H3` | Determine the current public GitHub redistribution/remediation disposition, including embedded notices, export, existing history, and forks | **PARTIAL — ACTIVE-TREE REMOVAL APPROVED; HISTORICAL/LEGAL DISPOSITION STILL REQUIRED; NO HISTORY REWRITE** |
| `H4` | Identify the individual/organization licensee, authorized acceptor/contact, and acceptable non-PII acceptance evidence | **MISSING / UNKNOWN — DO NOT RECONSTRUCT** |
| `H5` | Approve local-only build/use and decide whether hosted CI or a private archive cache satisfies the license/direct-control boundary | **P04B LOCAL-ONLY TECHNICAL BOUNDARY APPROVED; LICENSING/DIRECT-CONTROL AND HOSTED CI/CACHE REMAIN HUMAN / LEGAL REVIEW REQUIRED** |
| `H6` | Confirm that no toolkit-derived binary/container/CI artifact will be distributed unless separately approved | **NO DISTRIBUTION AUTHORIZED BY P04B; BROADER DISPOSITION REMAINS HUMAN / LEGAL REVIEW REQUIRED** |
| `H7` | If Option B is selected, authorize or defer removal of the current toolkit from the active tree; any Git-history rewrite is a separate destructive decision | **APPROVED 2026-08-27 — REMOVE ACTIVE TREE; NO HISTORY REWRITE** |
| `H8` | Approve the P04B contract below, including the dedicated build environment and scoped ignore changes | **APPROVED 2026-08-27 — CONTRACT FROZEN IN SECTION 14** |

P04B may start only under a separate implementation task and only within the
frozen section 14 boundary. The unresolved legal/provenance items above are not
silently resolved by the technical contract.

## 14. Frozen P04B scope and build contract

**Status:** Human-frozen on `2026-08-27`; implementation and evidence remain
`NOT_STARTED`.

P04B may implement only this acquisition, isolated build, and no-data verification
boundary:

```text
Human-provided local ZIP
  -> verify exact size and SHA-256
  -> isolated protected extraction
  -> dedicated toolkit-only Linux/amd64 build environment
  -> build reviewed dependency closure for dsdgen + tpcds.idx
  -> record artifact hashes and build manifest
  -> no-data verification
  -> STOP
```

### 14.1 Input contract

| Field | Frozen value / rule |
|---|---|
| Toolkit | TPC-DS Tools / DSGen `4.0.0` |
| Repository-relative archive path | `.local/tpcds/BBC82A1E-AE00-4C0B-9255-EBAF6CA0972B-TPC-DS-Tool.zip` |
| Archive size | Exactly `7,479,651` bytes |
| Archive SHA-256 | Exactly `d63e2bf093e23964b393364991be9fdd7a9cdd40fcdf91f99660eabde4c6162d` |
| Integrity meaning | Locally calculated retained-artifact identity; **not** a publisher-authenticated checksum or signature |
| Mismatch policy | Fail before extraction on missing file, non-regular file, size mismatch, or SHA-256 mismatch; no fallback source |

The P04B wrapper must resolve the path beneath the repository root, read the ZIP
without modifying it, and calculate its size and SHA-256 before extraction and
again after build verification. It must perform no download, TPC website access,
registration, EULA acceptance, or reconstruction of missing acquisition facts.

### 14.2 Extraction and source identity contract

- P04B must add/verify directory-scoped Git ignores before creating any workspace
  or output under `artifacts/tpcds_toolkit/`. It must not add broad rules such as
  `*.zip`, `*.dat`, or `*.parquet`.
- Use a unique workspace at
  `artifacts/tpcds_toolkit/.work/<toolkit_build_id>/` with separate `source/` and
  writable `build/` subdirectories. The resolved workspace must remain beneath
  `artifacts/tpcds_toolkit/.work/`, must not already exist, and must not be a
  symlink or reparse point. Refuse reuse or overwrite.
- Preflight every ZIP entry before writing. Reject absolute/rooted paths, drive or
  UNC prefixes, `..` traversal, paths that resolve outside `source/`, duplicate
  normalized paths, and entries represented as symlinks or other unsupported
  special files. Do not follow symlinks or reparse points during validation.
- Extract only into the empty ignored `source/` directory. Never extract into the
  repository root, tracked source, the historical toolkit path, or the final
  artifact directory.
- Treat extracted `source/` as immutable. Build only from a separate `build/`
  copy/worktree because the upstream Make graph writes generated files beside
  source files. Verify the immutable source identity again after the build.
- Create a deterministic extraction manifest with one regular-file record per
  normalized relative path: lowercase file SHA-256, byte size, and path, sorted by
  ordinal path order and serialized as UTF-8 with LF endings. Record the SHA-256
  of that serialized manifest as `source_manifest_sha256`.
- The retained ZIP must remain byte-for-byte unchanged. Extraction does not make
  the historical Git tree canonical and must not compare/fall back to it silently.

### 14.3 Dedicated build environment contract

- Use a toolkit-only Linux/`amd64` container/build environment, separate from and
  making no change to `LOCAL_YARN_V1`.
- Pin the base image by immutable digest, not a floating tag, and record its
  resolved OS release, architecture, libc, compiler, GNU Make, flex-or-lex,
  bison-or-yacc, and every auxiliary tool/package used by the reviewed dependency
  closure.
- Exact base-image digest and toolchain package versions are
  `TBD_P04B_RESOLVE_BEFORE_BUILD`. P04B must select, record, and fail closed on
  them before invoking any build command. No implicit host compiler/toolchain is
  allowed.
- Mount the archive and immutable extracted source read-only where practical. Give
  the builder write access only to the unique ignored build/output workspace.
- Do not embed toolkit packages, source, or build logic into the Spark/Hadoop
  runtime images or Compose topology.

### 14.4 Build target and command contract

Build only the reviewed dependency closure required to produce:

- `dsdgen` for Linux/`amd64`;
- `tpcds.idx`;
- runtime support files proven necessary for that exact `dsdgen`/`tpcds.idx`
  pairing.

The exact allowlisted command/working directory is
`TBD_P04B_AFTER_READ_ONLY_TARGET_GRAPH_REVIEW`. P04B must freeze it in project-owned
configuration before execution and record it as an argv array and display string
in the manifest. This TBD does not permit experimentation with broad upstream
targets.

Never invoke upstream `all`, `release`, `data_set`, cleanup/`clean`, database,
broad test, benchmark-generation, or dataset-generation workflows. Do not build
`dsqgen`, `checksum`, tests, or unrelated programs unless read-only target-graph
evidence proves a helper is in the minimum required dependency closure; record
that evidence and artifact disposition. Never execute `dsdgen` during P04B.

Do not invent or call a version flag. Bind executable identity primarily to the
archive/source manifest, frozen builder/toolchain, exact build command, and
observed binary hash. A no-data version invocation may be added only after source
evidence proves the exact invocation is supported and a Human-reviewed contract
amendment authorizes it.

### 14.5 Output and promotion contract

Successful local output uses this ignored, non-distribution layout:

```text
artifacts/tpcds_toolkit/<toolkit_build_id>/
├── bin/dsdgen
├── share/tpcds/tpcds.idx
├── build_manifest.json
└── logs/
```

`toolkit_build_id` must use:

```text
tpcds-tools-4.0.0-<archive-sha256-first12>-<builder-digest-first12>-<UTC-yyyyMMddTHHmmssZ>
```

Refuse an existing ID/path. Build and verify in `.work/<toolkit_build_id>/`; do not
populate the final artifact path until every required check passes. Promote the
complete directory as one bounded operation. Raw logs, source, objects, generated
headers, helpers, binaries, `tpcds.idx`, and manifests remain local and ignored.
They are not release, registry, CI, or redistribution artifacts.

### 14.6 Manifest contract

`build_manifest.json` uses schema identifier
`tpcds_toolkit_build_manifest/v1` and records at minimum:

- `toolkit_build_id`, toolkit name/version, manifest schema, and status;
- repository-relative archive path, observed archive size, SHA-256, and the fact
  that the checksum is locally calculated rather than publisher-authenticated;
- extracted root identity, deterministic extraction-manifest path/digest, source
  version evidence, and pre/post source identity checks;
- builder image reference/digest, OS/architecture, libc, compiler, GNU Make,
  flex-or-lex, bison-or-yacc, and auxiliary package/tool versions;
- exact working directory, environment inputs, allowlisted build argv/display
  command, and effective `DISTRIBUTIONS` reference;
- start/end UTC timestamps, final status, promotion status, code revision, and
  hashes of project-owned wrapper/config inputs;
- `dsdgen` relative path, platform/architecture, exact byte size, and SHA-256;
- `tpcds.idx` relative path, exact byte size, SHA-256, and generation/build
  lineage;
- any other retained runtime-support artifact path, purpose, size, and SHA-256;
- structured warnings, errors, anomaly/negative-result notes, and sanitized log
  references.

Unavailable acquisition provenance remains explicitly `null`/`MISSING`; do not
invent an original timestamp, temporary URL, publisher checksum, acceptor identity,
or acceptance record.

### 14.7 Failure policy

- Fail closed on input, path, extraction, source-manifest, version, builder,
  toolchain, command, output, or post-build verification mismatch.
- Never download or select another archive, use the removed vendored tree, change
  toolkit version, or silently change the builder/toolchain/command.
- Never promote partial outputs. Retain an ignored failure manifest and sanitized
  logs under the unique `.work/<toolkit_build_id>/` with status `FAILED`; leave no
  canonical `bin/` or `share/` artifact path.
- Never call upstream cleanup workflows to recover. A retry uses a new empty unique
  workspace and build ID while preserving negative evidence.
- No build or verification step may execute `dsdgen`, generate benchmark data, or
  contact HDFS, Spark, or YARN.

### 14.8 No-data verification and stop condition

One project-owned verification entry point must return explicit pass/fail and
confirm:

1. the archive still exists with the frozen byte size and SHA-256;
2. the immutable extracted-source manifest is unchanged;
3. the builder/toolchain and exact build command match the manifest;
4. `bin/dsdgen` exists, is a Linux/`amd64` executable, and has recorded size/hash;
5. `share/tpcds/tpcds.idx` exists and has recorded size/hash;
6. every retained runtime-support artifact and effective `DISTRIBUTIONS` reference
   is present and recorded;
7. no `.dat`, Parquet, dataset/materialization output, HDFS write, Spark action, or
   YARN action occurred;
8. no tracked source, historical toolkit path, or `LOCAL_YARN_V1` file changed;
9. no unsupported `dsdgen` version flag or generator invocation occurred; and
10. no partial output was promoted.

Compare two clean isolated builds under the same frozen inputs before claiming
bit reproducibility. Record mismatches as a negative result and do not claim bit
reproducibility when hashes differ.

P04B stops after the local build and no-data evidence is reviewed. It must not
generate TPC-DS benchmark data.

### 14.9 Values intentionally TBD until P04B

| Value | Required resolution point |
|---|---|
| Immutable builder base-image reference/digest | Before any build command |
| Exact compiler, GNU Make, flex-or-lex, bison-or-yacc, libc, and auxiliary versions | Before any build command |
| Exact minimum dependency closure and allowlisted build argv/working directory | After read-only target-graph review and before execution |
| Extracted-source manifest and `source_manifest_sha256` | After protected extraction, before build |
| Exact runtime-support list and effective `DISTRIBUTIONS` path | Before artifact promotion |
| `toolkit_build_id`, code revision, timestamps, builder identity, logs, and status | Per P04B build attempt |
| `dsdgen`, `tpcds.idx`, and support-artifact sizes/SHA-256 values | Observed after build, before promotion |

These TBDs are bounded observations/selections required by the frozen contract;
they are not permission to broaden P04B.

### Generated-data boundary

```text
TPC-DS toolkit
      ↓
dsdgen
------ P04B STOP BOUNDARY ------
      ↓
RAW generated TPC-DS data
      ↓
materialization
      ↓
Parquet/Snappy
      ↓
HDFS
      ↓
Spark workloads
```

P04A/P04B concern only acquisition, isolated build, and verified local runtime
artifacts. Dataset generation begins in P05 or later under its own approval.
Archives, extracted source, `.dat`, Parquet, binaries, objects, generated headers,
`tpcds.idx`, build directories, and temporary outputs remain outside Git unless a
later explicit contract states otherwise.

## 15. Explicit non-goals

This P04A decision/cleanup task does not implement acquisition or build tooling.
Under a separate implementation task, P04B may produce only the verified local
`dsdgen` and support artifacts defined in section 14; it must not publish or
distribute a toolkit binary/container. Neither task may:

- execute `dsdgen` or generate TPC-DS data;
- create a dataset-generation wrapper;
- materialize Parquet/Snappy or write HDFS;
- implement or submit Spark workloads;
- publish or distribute a toolkit binary or container image;
- alter TPC-DS source, EULA, or notices;
- change `TPCDS_DEBUG`, `TPCDS_SF1`, the six-table plan, or workload catalog;
- change `LOCAL_YARN_V1`, resolve `C1`, or run `EXP_001`;
- change collector, schema, feature/leakage, ML, recommendation, or evaluation
  contracts;
- self-approve T3 or any Research Gate. The T1/T2-related decisions recorded here
  are direct Human approvals and do not approve later gates.

P04A STATUS: HUMAN_APPROVED — OPTION B / ACTIVE-TREE REMOVAL

P04B CONTRACT: FROZEN / IMPLEMENTATION NOT_STARTED / DATA GENERATION NOT_STARTED
