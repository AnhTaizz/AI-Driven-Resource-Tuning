# Project Requirements Baseline

## 1. Purpose and Authority

This file is the stable requirements anchor for the AI-Driven Resource Tuning project. It preserves what the project is expected to address so that architecture, phase planning, and implementation do not silently drift from the supplied project brief.

- `PROJECT_STATE.md` records the current phase, approved decisions, open questions, and blockers.
- The remaining documents under `docs/` define how the requirements are designed, implemented, and evaluated.
- This file does not prove that a requirement has been implemented; evidence must come from code, tests, datasets, and experiments.

Disposition meanings:

- `CORE`: required for the MVP/final deliverable.
- `CONDITIONAL`: required only when the available data supports it; an explicit fallback is mandatory.
- `SECONDARY`: useful comparison, but not required for the primary research claim.
- `PENDING_DECISION`: present in the project brief but its exact MVP treatment requires human approval; it may not be silently dropped.
- `FUTURE_WORK`: explicitly outside the MVP and retained as an extension.

## 2. Problem and Research Boundary

Spark resource configurations such as executor count, cores per executor, executor memory, memory overhead, and driver memory are often selected using defaults or individual experience. This can cause:

- over-provisioning, which wastes resources and occupies cluster/queue capacity;
- under-provisioning, which increases runtime and may cause spill, OOM, or failure.

The project must build a history-aware recommendation system that learns the relationship between:

```text
(pre-run workload information, strictly earlier historical context, candidate configuration)
    -> expected execution performance/risk
```

The system then recommends a valid resource configuration for a future Spark execution and explains the evidence behind that recommendation.

The project is about resource recommendation from execution history. It is not an attempt to modify Spark engine internals, replace the Spark/YARN scheduler, or claim autonomous production tuning.

## 3. Requirement Traceability

| ID | Requirement | Disposition | Current interpretation / boundary |
|---|---|---|---|
| `REQ-01` | Collect execution evidence from Spark History Server, Spark event logs/listener-derived events where needed, and YARN ResourceManager. | CORE | Exact endpoints and fields must match the Spark/Hadoop versions actually used. Raw payloads remain immutable. |
| `REQ-02` | Extract input size/partitions, stage/task counts, shuffle read/write, skew, peak memory, utilization, runtime, status, spill/OOM evidence, and the resource configuration used. | CORE | Same-run outcomes are post-run observations, not pre-submit inputs for that same execution. Unavailable metrics remain explicitly missing. |
| `REQ-03` | Build a historical dataset from authorized company executions or diverse, clearly labeled benchmark/simulated workloads. | CORE | The approved MVP controlled source is a non-official TPC-DS-based benchmark under ADR-0004. Real-company, benchmark, and official TPC results must never be presented as the same source. Coverage matters more than an arbitrary row count. |
| `REQ-04` | Learn execution performance from workload/history/configuration inputs. | CORE | The approved MVP target is runtime prediction. Resource cost is derived from candidate resources and predicted runtime where valid. |
| `REQ-05` | Account for utilization, spill, OOM, and failure risk. | CONDITIONAL | Collect and report observed evidence where the source provides it. Train a reliability model only if label quality/volume is sufficient; otherwise use a transparent rule-based estimator and document the limitation. |
| `REQ-06` | Evaluate a direct configuration recommendation approach. | CORE | A transparent direct heuristic recommender satisfies the required first approach and is a mandatory baseline. Direct config regression remains a `SECONDARY` comparison because reliable “optimal config” labels may not exist. |
| `REQ-07` | Evaluate simulation-style candidate search and select a Pareto-efficient runtime/resource trade-off. | CORE | Generate valid candidate configurations, predict outcomes, derive resource cost, apply Pareto/constraints, then apply an explicit recommendation policy. |
| `REQ-08` | Handle jobs with multiple SQL nodes running in parallel using aggregate resource estimation rather than naive per-stage treatment. | CORE | MVP boundary: concurrent SQL executions/stages inside one Spark application. Preserve timing/membership and aggregate by interval overlap; do not sum stage runtimes/resources. Multi-application workflow recommendation is outside the MVP. |
| `REQ-09` | Recommend a configuration before submission for a known or supported new workload. | CORE | Use only information available at recommendation time. Return `NO_SAFE_RECOMMENDATION` and an explicitly labeled baseline fallback when coverage is insufficient. |
| `REQ-10` | Improve recommendations after additional executions are observed (feedback loop). | CORE | MVP uses an explicit offline/manual loop: collect, rebuild/version dataset, retrain, validate, and promote a new model. Automated retraining is future work. |
| `REQ-11` | Warn about clear resource waste or shortage, including high idle time, spill, and OOM signals. | CORE | MVP provides evidence-backed post-run diagnostic warnings. Live running-job monitoring is a stretch goal and must not be claimed as implemented by History Server-only diagnostics. |
| `REQ-12` | Compare recommendations with current/default and meaningful non-ML baselines. | CORE | At minimum: current/default, nearest historical/similar-job, simple heuristic, and ML + optimization under the same evaluation protocol. |
| `REQ-13` | Evaluate diverse workloads and resource regions. | CORE | Include small/medium/large scales and ETL, aggregation, join, shuffle, and skew behavior where practical; quantify uncovered regions and noise. |
| `REQ-14` | Provide a demo for selecting/providing a supported job, analyzing history, recommending resources, comparing with a baseline, and explaining the recommendation. | CORE | The UI must distinguish observed, derived, predicted, and recommended values and expose no-safe-recommendation behavior. |
| `REQ-15` | Report resource consumption change and runtime impact on at least one experimental workload set. | CORE | Final savings claims must use observed Spark validation, not predictions alone. The exact resource-cost boundary and unit must be named. |
| `REQ-16` | Provide source code and deployment, Spark History Server/YARN connection, dataset generation, and model train/retrain guidance. | CORE | These are final documentation deliverables even if automated retraining is outside the MVP. |
| `REQ-17` | Report limitations and extension directions. | CORE | Include weak coverage for unseen jobs, data/source limitations, cluster differences, and negative validation results. |
| `REQ-18` | Real-time auto-tuning and direct scheduler integration. | FUTURE_WORK | These are extension directions, not MVP claims or automatic production actions. |

## 4. Decisions That Must Not Be Lost

| Decision | Why it matters | Required before |
|---|---|---|
| Runtime degradation guardrail and reliability threshold | Determines which Pareto candidate may be recommended. | Recommendation Gate |

Accepted scope decisions are recorded in `docs/adr/ADR-0001-mvp-runtime-and-scope.md` through `docs/adr/ADR-0004-adopt-tpc-ds-as-controlled-benchmark-foundation.md`.

Record decisions in `PROJECT_STATE.md`. Create an ADR when a decision changes architecture, schema meaning, feature availability, evaluation, model formulation, or recommendation policy.

## 5. Minimum Final Evidence

The final project must provide:

1. traceable Spark/YARN source data with explicit versions and missingness;
2. a versioned, leakage-safe historical dataset and coverage report;
3. reproducible current/default, nearest-history, and heuristic baselines;
4. a runtime model and candidate-search recommendation path;
5. a valid recommended configuration with an evidence-based explanation;
6. actual Spark executions of baseline and recommended configurations on frozen validation workloads;
7. observed resource-consumption and runtime comparisons, including cases where the recommendation loses;
8. a usable demo plus deployment/connection/train/retrain documentation;
9. explicit assumptions, limitations, unsupported cases, and future work.

No fixed accuracy or savings percentage is assumed before data exists. Any quantitative success threshold must be approved and recorded before final evaluation.

## 6. Scope Change Control

- A requirement is not satisfied merely because it appears in an architecture or phase document; implementation evidence is required.
- A `CORE` requirement may not be downgraded, removed, or materially reinterpreted without explicit human approval.
- A `PENDING_DECISION` item must receive a recorded disposition; omission is not a decision.
- If data cannot support a requested model or metric, preserve the requirement history, record the evidence, and use the smallest transparent fallback allowed by the research contract.
- Any approved scope change must update this file and `PROJECT_STATE.md`; create an ADR when required by `engineering_standards.md`.
