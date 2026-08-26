# TPC-DS Toolkit Integration Review

- Task: `P04A` — TPC-DS Toolkit Integration Review Gate
- Review date: `2026-08-26`
- Repository revision reviewed: `e174cbdea01806f5df51ad570e207d02743d3eb9`
- Review status: **PENDING HUMAN DECISION**
- Proposed strategy: **Option B — external/pinned upstream acquisition**
- Fallback: **Option A — keep vendored source**, only under the conditions in section 12

This packet is decision support, not approval or implementation. It preserves the
planning contracts in [ADR-0004](adr/ADR-0004-adopt-tpc-ds-as-controlled-benchmark-foundation.md)
and the [TPC-DS implementation plan](tpcds_implementation_plan.md). No toolkit was
built or executed, and no benchmark data was generated.

## 1. Current state

- TPC-DS remains `PLANNED / NOT_STARTED`; the Data Gate remains `NOT_APPROVED`.
- The repository contains an extracted third-party toolkit tree at
  `B0CF2ADA-2F20-4296-A89C-81B8202DCD13-TPC-DS-Tool/`.
- Project-owned benchmark generation, dataset, workload, and experiment directories
  contain placeholders only. No TPC-DS integration code exists.
- No compiled generator, `tpcds.idx`, generated `.dat`, Parquet dataset, or
  implemented TPC-DS Spark workload was found.
- The entire toolkit is tracked in Git. It is neither a submodule nor a Git LFS
  object and has no explicit `third_party` or `vendor` boundary.
- Git shows no toolkit changes after its introduction, but this establishes only
  repository identity, not authenticity against an upstream archive.

The current tree must not be treated as an approved source, build, or project
evidence until the Human and legal/governance decisions below are resolved.

## 2. Toolkit inventory

### 2.1 Identity and contents

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

No cleanup is performed by P04A. Ignore rules alone would not untrack existing
files.

## 6. Build and reproducibility gaps

The repository currently has no approved project-owned contract for:

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

## 11. Recommended option — PROPOSED

Recommend exactly **Option B — external/pinned upstream acquisition** for
AI-Driven Resource Tuning.

This is the smallest reliable solution for the current local/research scope:

1. it creates a truthful acquisition record rather than retroactively treating an
   unexplained Git tree as upstream-authenticated;
2. it keeps third-party source, archives, binaries, and generated data out of the
   main project history;
3. it supports Windows development through a small, separate pinned Linux Docker
   build without changing `LOCAL_YARN_V1`;
4. it avoids the registry/artifact-management complexity of Option C;
5. it can reproduce historical data when the exact accepted archive, lock record,
   builder identity, `dsdgen`, and `tpcds.idx` are retained under an approved
   non-public artifact policy.

The canonical acquisition should be Human-mediated. The future wrapper should
accept a local archive path, verify it, and never download the toolkit or automate
EULA acceptance.

This recommendation is **PENDING HUMAN DECISION**. It is not approval to remove
the current tree, acquire the archive, build anything, or publish artifacts.

## 12. Fallback option

Fallback to **Option A — keep vendored source** only if:

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
| `H1` | Select Option B, select the conditional fallback, or reject both | **PENDING HUMAN DECISION** |
| `H2` | Determine whether the non-official academic/research use is permitted given the EULA and specification Appendix F | **HUMAN / LEGAL REVIEW REQUIRED** |
| `H3` | Determine the current public GitHub redistribution/remediation disposition, including embedded notices, export, existing history, and forks | **HUMAN / LEGAL REVIEW REQUIRED** |
| `H4` | Identify the individual/organization licensee, authorized acceptor/contact, and acceptable non-PII acceptance evidence | **PENDING HUMAN DECISION** |
| `H5` | Approve local-only build/use and decide whether hosted CI or a private archive cache satisfies the license/direct-control boundary | **HUMAN / LEGAL REVIEW REQUIRED** |
| `H6` | Confirm that no toolkit-derived binary/container/CI artifact will be distributed unless separately approved | **PENDING HUMAN DECISION** |
| `H7` | If Option B is selected, authorize or defer removal of the current toolkit from the active tree; any Git-history rewrite is a separate destructive decision | **PENDING HUMAN DECISION** |
| `H8` | Approve the P04B contract below, including the dedicated build environment and scoped ignore changes | **PENDING HUMAN DECISION** |

P04B must not start until the decisions needed for its exact scope are recorded.

## 14. Proposed P04B scope and target contract

P04B should implement only the approved toolkit acquisition/build boundary. The
following contract is **PROPOSED**, not executed.

| Contract area | P04B target |
|---|---|
| Toolkit version | Pin TPC-DS Tools/DSGen `4.0.0`; reject any version or source-tree mismatch. A version change requires a new reviewed contract. |
| Provenance lock | Add a version-controlled, machine-readable record for authoritative page/request URLs, expected archive name, observed archive bytes/SHA-256, acquisition timestamp/evidence, EULA/spec versions and digests, extracted-file manifest digest, and wrapper code revision. Do not commit personal registration data or temporary links. |
| Acquisition | Require a Human-supplied local archive obtained through the approved flow. The wrapper performs no network download and no acceptance action. |
| Build environment | Create a toolkit-only, pinned Linux/`amd64` builder identified by immutable base-image digest and exact compiler, Make, libc, and required auxiliary-tool versions. Do not alter or embed this into `LOCAL_YARN_V1`. |
| Isolation | Mount the input read-only; verify it before extraction; reject path traversal/symlinks and non-empty targets; extract/build in a unique ignored workspace; never modify the committed/current vendor tree. |
| Build wrapper | Provide one Windows PowerShell 5.1-compatible entry point backed by an allowlisted container build step. Build only the reviewed dependency closure for `dsdgen` and `tpcds.idx`; never invoke upstream release, dataset, test, or cleanup workflows. Freeze the exact command only after reviewing the target graph during P04B. |
| Artifact root | Proposed local ignored root: `artifacts/tpcds_toolkit/<toolkit_build_id>/`. It is not a distribution location. |
| Binary path | Canonical proposed Linux path: `artifacts/tpcds_toolkit/<toolkit_build_id>/bin/dsdgen`. Record filename, platform/architecture, byte size, SHA-256, source lock, builder digest, toolchain, and resolved build command. |
| Executable identity | Verify source version 4.0.0 and use a separately reviewed no-data runtime identity invocation if the actual binary supports one. Do not invent a version flag. Bind identity primarily through the build manifest and binary digest. |
| `tpcds.idx` | Treat it as a required build/runtime support artifact, not dataset data. Proposed path: `artifacts/tpcds_toolkit/<toolkit_build_id>/share/tpcds/tpcds.idx`; record size/SHA-256/generation lineage and use an explicit resolved `DISTRIBUTIONS` path. |
| Logs and manifest | Record start/end UTC timestamps, status, exact resolved command, source/archive IDs, builder/tool versions, output hashes, warnings, and sanitized failure details. Keep raw logs local/ignored; commit only the approved non-sensitive lock/contract metadata. |
| Error handling | Fail closed on checksum, version, manifest, toolchain, path, or output mismatch. Never promote partial output, silently change toolchains, fall back to the current tree, run upstream tests, or delete source/data through upstream cleanup targets. |
| Ignore boundary | Add scoped rules for the approved archive cache, extraction/build roots, objects, generated headers, markers, binaries, `tpcds.idx`, logs, raw `.dat`, Parquet, and temporary generator outputs. Prefer directory-scoped rules over hiding all files of a common extension. |
| Repeatable verification | Provide one project-owned no-data verification command that checks the lock, source/extraction manifest, builder identity, binary and `tpcds.idx` hashes, and approved version evidence; asserts no generator/materialization outputs and no source mutation; and returns explicit pass/fail. Compare two clean builds before claiming bit reproducibility and record any negative result. |
| Repository disposition | If and only if `H3`/`H7` authorize it, remove the toolkit from the active tree under a separately reviewed mutation. Do not rewrite Git history without distinct explicit authorization. |

P04B should stop after reproducible build evidence is reviewed at the applicable
toolkit gate. It must not generate TPC-DS data.

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

P04A does not implement any acquisition or build strategy. If approved, P04B may
produce only the verified local `dsdgen` and support artifacts defined in section
14; it must not publish or distribute a toolkit binary/container. Neither task may:

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
- approve T1/T2/T3 or any Research Gate.

P04A STATUS: READY_FOR_HUMAN_DECISION
