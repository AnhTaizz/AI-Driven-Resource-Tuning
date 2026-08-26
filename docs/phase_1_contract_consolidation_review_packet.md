# Phase 1 Contract and Repository Consolidation — Human Review Packet

## 1. Decision Status

- Packet status: **AWAITING_HUMAN_TECH_LEAD_DECISION**
- Prepared: **2026-08-26**
- Scope: documentation and decision preparation only
- Current environment state: **LOCAL_YARN_V1 = VERIFIED**
- Current research gate: **Data Gate = NOT_APPROVED**
- Bootstrap configuration: **C1 = TBD**

This packet does not approve a Research Gate, change an architecture or data
contract, authorize collector implementation, build the TPC-DS toolkit,
generate or materialize data, implement workloads, run Spark, resolve C1, or
authorize EXP_001.

The Human Tech Lead must select the decisions below before an agent updates the
affected contracts. Recommendations in this packet are proposals, not approved
project state.

## 2. Why This Review Is Required

The read-only audit found that the approved research principles are sound, and
that the P01 TPC-DS migration and P03 environment transition are internally
consistent in the current worktree. The project is not yet ready to freeze the
normalized execution/dataset semantics because the following boundaries remain
ambiguous:

1. how multiple Spark History and YARN attempts map to one approved
   application-level execution;
2. which terminal statuses are valid runtime-regression targets;
3. the authoritative pre-run/as-of timestamp and temporal split boundary;
4. the deterministic, versioned definition of job family;
5. canonical metric naming and source-resolution rules;
6. phase/component ownership for concurrency and post-run diagnostics.

The audit also found two repository-lineage issues:

1. the accepted P01/P03 documentation exists only in the dirty local worktree,
   while the current Git revision still contains the older planned environment
   state;
2. the approved LOCAL_YARN_V1 evidence is ignored by Git and therefore is not
   independently retrievable from a clean clone.

These findings do not revoke the Human approval of LOCAL_YARN_V1. They limit how
that decision and its evidence can currently be reproduced outside this
worktree.

## 3. Audit Disposition

| Area | Disposition | Reason |
|---|---|---|
| Phase 0 framing | **CONDITIONAL** | Core principles are documented, but the six semantics above are not frozen |
| P01 TPC-DS documentation | **CONTENT PASS / DURABILITY OPEN** | IDs, scope, workload plan, terminology, and stop boundary are coherent; accepted files are not committed |
| P02/P03 environment review | **SCOPED PASS / DURABILITY OPEN** | The exact Human-approved session and snapshot are consistently referenced; local evidence is not durable from Git |
| LOCAL_YARN_V1 | **VERIFIED — UNCHANGED** | Human approval remains scoped to infrastructure identity and plumbing |
| Data Gate | **NOT_APPROVED — UNCHANGED** | No benchmark dataset or canonical historical execution dataset exists |
| C1 | **TBD — UNCHANGED** | No resource configuration is selected here |

## 4. Human Decisions Requested

### P04-D01 — Accepted-documentation commit boundary

**Option A — One honest P01–P03 documentation baseline (recommended)**

- Commit the accepted P01, P02, and P03 documentation/state together because
  several new and mixed files already contain both P01 and P03 content.
- Explicitly exclude the unrelated observability implementation and the Excel
  workbook.
- Use explicit file/hunk staging and review the staged diff. Do not use broad
  staging commands.

This preserves the actual reviewed state without reconstructing a historical
intermediate version from memory.

**Option B — Reconstruct separate P01 then P02/P03 commits**

- Recreate and review the exact P01-only intermediate documents.
- Commit P01 first and P02/P03 second.

This gives cleaner history but carries a higher risk of inventing an
intermediate state that never existed as reviewed files.

**Option C — Leave the accepted state uncommitted**

Not recommended. A clean clone would continue to report
LOCAL_YARN_V1 as planned and would omit the accepted TPC-DS documents.

**Decision:** PENDING

### P04-D02 — Durable verification-evidence retention

**Option A — Immutable external archive plus tracked manifest (recommended)**

- Copy the exact evidence bytes to immutable, versioned, access-controlled
  storage.
- Commit a deterministic post-hoc integrity manifest containing artifact paths,
  byte sizes, SHA-256 values, storage URI/version/retention metadata, the exact
  approved IDs, and all historical session statuses.
- Record the execution-time code revision as missing because it was not
  captured. Do not infer the current Git revision.

**Option B — Force-track sanitized evidence after security review**

- Review host process details, local paths, container IDs, and logs for
  disclosure risk.
- Commit the exact approved and historical evidence only after that review.

The evidence volume is small enough for Git, but size does not resolve privacy
or public-repository concerns.

**Option C — Keep local ignored evidence only**

Not sufficient for independent reproduction. It may remain a temporary state
but must be labeled **LOCAL_ONLY_NOT_DURABLY_ARCHIVED**.

Any manifest created now must be labeled
**POST_HOC_INTEGRITY_MANIFEST**. It may authenticate the bytes observed when the
manifest is created, but it cannot retroactively prove capture-time
immutability. Missing revision, EventLog digest, attempt-placement, or
clock-drift evidence must remain explicitly **NOT_CAPTURED**; none may be
reconstructed or invented.

**Decision:** PENDING

### P04-D03 — Phase 0 contract disposition

**Option A — Keep Phase 0 contract closure pending until P04-D04 through
P04-D09 are approved (recommended)**

- Preserve the already approved framing.
- Treat the unresolved items as contract decisions, not implementation details.
- Record approved choices in a new ADR and update all affected contracts in a
  separately authorized documentation task.

**Option B — Freeze the current documents without resolving the ambiguities**

Not recommended. Different collectors or dataset builders could make
incompatible choices while still appearing contract-compliant.

**Decision:** PENDING

### P04-D04 — Canonical application and attempt semantics

The already approved modeling unit remains one Spark application execution.
The open question is how source attempts map into that application record.

**Option A — Application parent with source-qualified attempt children
(recommended)**

- One canonical execution corresponds to one Spark application submission.
- Preserve every Spark History attempt and YARN ApplicationMaster attempt as a
  source-qualified child record.
- Do not assume that Spark attempt IDs and YARN attempt IDs are equivalent.
- Do not silently select the latest attempt or aggregate attempt runtime/cost.
- Initially exclude multi-attempt applications from runtime regression until a
  separately approved aggregation rule exists.

**Option B — Treat each attempt as a canonical execution**

Not recommended for the MVP. It can count one submission multiple times and
changes the approved unit, split semantics, experiment-repeat count, and
recommendation target.

**Option C — Maintain independent application-grain and attempt-grain modeling**

Potentially complete but materially expands schema, modeling, and evaluation
scope beyond the MVP.

**Decision:** PENDING

### P04-D05 — Runtime-target eligibility

**Option A — Successful-completion runtime only (recommended)**

- Populate the runtime target only for eligible SUCCEEDED executions with valid
  timing evidence.
- Preserve FAILED, KILLED, UNKNOWN, and excluded rows as immutable and
  normalized evidence.
- Record an explicit eligibility flag and exclusion reason.
- Keep elapsed time to failure/kill as an observed diagnostic when available,
  never as successful completion runtime.
- Do not relabel KILLED as failure or OOM without explicit evidence.

**Option B — Use elapsed time for every terminal status**

Not recommended. It mixes time-to-success with time-to-failure and can reward a
configuration that fails quickly.

**Option C — Introduce survival, competing-risk, or multi-task modeling**

Defer unless a future Dataset Gate demonstrates adequate labels and a separate
architecture/evaluation decision authorizes the added scope.

**Decision:** PENDING

### P04-D06 — As-of and temporal evaluation semantics

**Option A — Global anchored temporal cutoffs (recommended for the MVP)**

- Define as-of time as a UTC recommendation/experiment-freeze timestamp
  captured before submission.
- For benchmark reconstruction, use the explicit freeze timestamp first, then
  YARN submission time only as an approved fallback; otherwise exclude the row
  instead of silently substituting Spark start time.
- Historical outcomes are eligible only when their finish time is strictly
  earlier than the target as-of time.
- Freeze dataset-wide train and validation end timestamps rather than computing
  independent per-family quantiles.
- Track A applies the global time anchors and requires strictly earlier
  permitted history for each evaluated target.
- Track B combines global time anchors with disjoint family sets; a test
  family's rows never enter training or target-family historical context.
- Candidate configurations/repeats in one evaluation block share one
  pre-execution cutoff and cannot learn from each other.
- Retrospective collection may use a named, versioned source-event-time
  reconstruction rule only when the outcome existed before the cutoff; it must
  not be presented as operational ingestion-latency evidence.

**Option B — Per-family temporal quantiles**

Not recommended. Training can include another family's future relative to a
target execution.

**Option C — Rolling-origin evaluation**

Potentially stronger later, but it adds split, refit, and reporting complexity.
Defer for the initial MVP unless explicitly selected.

**Decision:** PENDING

### P04-D07 — Deterministic job-family identity

**Option A — Versioned registry mapping (recommended)**

For the controlled benchmark, family identity is derived from:

    provenance_class = TPCDS_CONTROLLED
    workload_id
    workload_version

Dataset ID/version, scale, seed, experiment, repeat, resource configuration,
and environment do not change family identity. Persist the rule version,
registry reference/checksum, and mapping source. A workload-version change
initially creates a new family. Non-benchmark jobs require reviewed registry
entries; never infer family from an application name alone.

Example identifier:

    JF_TPCDS_CONTROLLED_W03_TPCDS_JOIN_WV1

**Option B — Workload ID only**

Not recommended because semantic workload revisions would collapse into one
family.

**Option C — SQL/plan fingerprint**

Defer. It can be version-sensitive, unstable, or known only after execution.

Track B must report limited/unsupported generalization if the initial six
families do not provide adequate unseen-family coverage.

**Decision:** PENDING

### P04-D08 — Metric namespace and source resolution

**Option A — Origin-explicit canonical namespace and versioned resolution
(recommended)**

- Use observed, derived, predicted, candidate, and recommended prefixes
  consistently.
- Preserve each source-specific observation.
- Create a canonical metric only through a named, versioned resolution rule.
- Preserve Spark and YARN runtime/status observations separately.
- Never substitute YARN elapsed time for Spark application runtime silently.
- Preserve conflicting evidence and explicit missing reasons.
- Do not merge semantically different memory measures.
- Record definition version, source system/field, aggregation version, and
  quality flags for every resolved metric.
- Freeze exact Spark 3.5.9/Hadoop 3.3.6 field precedence only after Phase 1
  captured fixtures establish availability and semantic equivalence.

**Option B — Keep the current mixed short and origin-prefixed names**

Not recommended because data_schema.md and metric_catalog.md can describe the
same value differently.

**Option C — Retain only source-native fields with no canonical layer**

Safe for immutable raw collection, but insufficient by itself for normalized
dataset/model contracts.

The Human decision must also select one schema-version treatment:

- **A1 — Amend execution_v1 in place (recommended):** no normalized
  implementation or frozen execution_v1 dataset exists, so correcting the draft
  does not reinterpret a released artifact.
- **A2 — Publish execution_v2:** preserve execution_v1 as a superseded draft and
  place the clarified contract under a new version. This adds lineage ceremony
  without protecting any implemented consumer.

**Decision:** PENDING

### P04-D09 — Ownership of concurrency and post-run diagnostics

**Option A — Explicit cross-phase ownership with a separate diagnostics concern
(recommended)**

- Phase 1 captures source-native SQL/stage membership, intervals, status,
  spill, CPU/run-time, memory, OOM/failure, and diagnostic evidence.
- Phase 2 normalizes half-open concurrency intervals and derives versioned
  application-level overlap facts without double-counting resources.
- Phase 2 also creates a separate deterministic post-run diagnostics concern;
  its outputs are not same-run model features.
- Phase 3 produces observed coverage and never manufactures OOM, spill, skew,
  or concurrency.
- Phase 4 freezes coverage, missingness, and leakage-safe historical features.
- Phase 7 validates interval accounting and evidence-backed warning rules.
- Phase 8 presents post-run diagnostics without converting them into live
  intervention or prediction.

Every warning records rule/threshold version, evidence, source/aggregation,
severity, uncertainty, and POST_RUN availability. OOM without an explicit
signal remains UNKNOWN. Low CPU evidence must not be described as whole-cluster
idle.

**Option B — Keep ownership implicit across the collector, feature, and UI
layers**

Not recommended because it risks target leakage and inconsistent diagnostic
logic.

Adding a separate diagnostics component is an architectural boundary and must
be explicitly approved before implementation.

**Decision:** PENDING

### P04-D10 — Recommendation-policy decisions

**Option A — Explicitly defer to the Recommendation Gate (recommended)**

Continue tracking, without selecting:

- runtime degradation guardrail;
- risk threshold;
- reference runtime;
- resource-cost objective and resource boundary;
- confidence/coverage rule for NO_SAFE_RECOMMENDATION.

These choices do not block immutable raw collection, but they must be frozen
before recommendation evaluation and must not be tuned on frozen test results.

**Option B — Open a separate recommendation-policy decision task now**

This is valid only under explicit authorization and is outside this packet.

**Decision:** PENDING

## 5. Safe Boundary Before Decisions Are Recorded

A future explicitly authorized raw-collection task may safely:

- append immutable source payloads from Spark History/EventLog and YARN;
- preserve every source-native ID, attempt, timestamp, state, diagnostic, and
  artifact checksum;
- keep source-system namespaces explicit;
- distinguish collector status from application status;
- report missing fields without imputation.

It must not yet:

- create a canonical execution ID from ambiguous attempts;
- equate Spark and YARN attempt IDs;
- choose a terminal/latest attempt;
- aggregate runtime, status, or cost across attempts;
- create runtime targets, eligibility labels, job families, temporal splits, or
  canonical metric fallbacks.

## 6. Proposed Repository Consolidation Sequence

No step in this section is executed by this packet.

1. Confirm ownership of the Excel workbook and the untracked observability work.
2. Select P04-D02 and validate retrieval/security/hash behavior.
3. Preserve the dirty original worktree and perform consolidation from the
   current Git base in an isolated clean worktree or branch.
4. Apply P04-D01 using explicit staging and inspect the staged file list and
   diff.
5. Validate links, stale IDs/statuses, whitespace, and all infrastructure
   static/regression contracts.
6. Handle observability sources, documentation, and tests atomically only under
   separate authorization.
7. Handle the Excel workbook in its own reviewed change unless its owner assigns
   it to an existing task.

Do not use a tracked-only broad commit: it would stage the deletion of
synthetic_data_spec.md while omitting its untracked replacement and other new
accepted documents. Do not use broad all-file staging: it would mix
documentation, observability, and the binary workbook.

## 7. Human Decision Record

The Human Tech Lead may answer with one selected option per item and any
conditions:

| Decision | Selection | Conditions/notes |
|---|---|---|
| P04-D01 commit boundary | PENDING | |
| P04-D02 evidence retention | PENDING | |
| P04-D03 Phase 0 disposition | PENDING | |
| P04-D04 application/attempt semantics | PENDING | |
| P04-D05 runtime-target eligibility | PENDING | |
| P04-D06 temporal/as-of semantics | PENDING | |
| P04-D07 job-family identity | PENDING | |
| P04-D08 metric namespace/resolution | PENDING | Include execution_v1 versus execution_v2 |
| P04-D09 concurrency/diagnostics ownership | PENDING | |
| P04-D10 recommendation decisions | PENDING | |

Approval of an option authorizes only recording the decision in the affected
ADR/contracts when a later task explicitly requests that update. It does not
authorize implementation or advance a Research Gate.

## 8. Exact Recommended Next Task

**Human Tech Lead review of P04-D01 through P04-D10.**

After the Human records those decisions, the next separately authorized task
should create the corresponding ADR and update only the affected architecture,
data, feature, metric, evaluation, phase, testing, and project-state contracts.
It must stop after documentation validation and must not implement collectors,
TPC-DS integration, workloads, benchmark runs, ML, optimization, or
recommendations.
