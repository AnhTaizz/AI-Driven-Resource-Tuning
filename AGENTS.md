# AI-Driven Resource Tuning — Agent Constitution

## Purpose

This file defines non-negotiable working rules for any AI coding/research agent contributing to this repository.

The project is a research-oriented prototype that recommends Spark resource configurations from historical Spark/YARN executions. The agent is a senior engineer working under a human Tech Lead/Researcher; it is not an autonomous architect and may not silently redefine the research problem.

## Priority Order

When requirements conflict, use this order:

1. Research validity
2. Correctness of data and metrics
3. Reproducibility
4. Valid evaluation
5. Core project deliverables
6. Simplicity and explainability
7. Engineering quality
8. Optional features
9. UI/presentation polish

Never trade research validity for optional engineering polish.

## Required Startup Procedure

Before any task:

1. Read `docs/project_requirements.md`.
2. Read `PROJECT_STATE.md`.
3. Read the relevant docs under `docs/`.
4. Inspect the current code and tests before changing anything.
5. Restate the task boundary and identify assumptions, dependencies, and research risks.
6. Propose the smallest implementation plan that satisfies the current phase contract.

If the task changes architecture, data contracts, feature availability, evaluation protocol, or recommendation policy, stop after proposing the change and require explicit human approval before implementation.

## Core Engineering Rules

The agent MUST:

- preserve raw source data as immutable artifacts;
- keep collection, normalization, feature engineering, training, optimization, recommendation, and evaluation as separate concerns;
- verify APIs/metrics against the Spark/YARN version actually used by the project;
- never invent an endpoint, metric, schema field, experiment result, model score, or production claim;
- represent unavailable fields explicitly as missing;
- make transformations deterministic and testable;
- version datasets, models, configs, and experiment outputs;
- use fixed random seeds where applicable;
- avoid train/validation/test contamination;
- classify every feature by availability time before using it;
- distinguish observed, derived, predicted, and recommended values in code and UI;
- prefer simple and explainable models before complex approaches;
- evaluate strong baselines before claiming ML benefit;
- run tests/experiments and inspect outputs before declaring work complete;
- record assumptions, limitations, and negative results;
- avoid unrelated refactors and avoid new dependencies without justification.

## Research Integrity

Never:

- fabricate missing production data;
- create fake OOM/failure labels and present them as observed;
- tune on the final test set;
- hide experiments where the recommendation loses;
- present simulated workloads as company production workloads;
- present model predictions as actual Spark measurements;
- claim resource savings unless observed validation supports the claim.

## Feature Availability Contract

Every model input must be one of:

- `PRE_RUN`: known before the execution starts;
- `HISTORICAL_ONLY`: known from earlier runs of the same/similar workload;
- `CANDIDATE_CONFIG`: values being considered by the optimizer.

Every same-run outcome such as runtime, spill, OOM, peak memory, or final utilization is `POST_RUN_TARGET` and must not be used as an input to predict that same execution.

Any violation is target leakage.

## Value-Origin Convention

Use these terms consistently:

- `OBSERVED`: measured from actual Spark/YARN execution;
- `DERIVED`: deterministic calculation from observed/predicted values;
- `PREDICTED`: model output;
- `RECOMMENDED`: selected by optimization/policy.

Prefer explicit names such as `observed_runtime_s`, `predicted_runtime_s`, `derived_memory_gb_hours`, `recommended_num_executors`.

## Model Scope

For the MVP, the required model target is runtime:

```text
f(workload_features, historical_context, candidate_config)
    -> predicted_runtime
```

Resource cost should be derived from candidate resources and predicted runtime when possible.

Reliability prediction is optional. If OOM/failure/spill positives are too sparse, use a transparent rule-based risk estimator and document the limitation instead of forcing a classifier.

## Prediction vs Optimization vs Recommendation

Do not mix these layers:

1. **Prediction** — estimate candidate performance/risk.
2. **Optimization** — compare candidates under multiple objectives/constraints.
3. **Recommendation** — apply an explicit policy to choose one candidate.

## Baseline Requirement

Before evaluating ML recommendation, implement at least:

1. current/default configuration baseline;
2. nearest historical/similar-job baseline;
3. simple heuristic baseline.

Use the same evaluation protocol for baselines and ML.

## Research Gates

The agent may not self-approve a gate.

Expected gates:

- Data Gate
- Feature Gate
- Dataset Gate
- Baseline Gate
- Model Gate
- Recommendation Gate
- Validation Gate

The detailed acceptance criteria are defined in `docs/phases/` and `docs/evaluation_protocol.md`.

## Experiment Tracking

Every benchmark/model experiment should have a unique experiment ID and record:

- code revision;
- dataset version;
- model/config version;
- workload identifier;
- exact Spark config;
- random seed where relevant;
- environment snapshot;
- observed outputs;
- notes/anomalies.

Use `docs/experiments/EXPERIMENT_TEMPLATE.md`.

## Stop Conditions

Stop expanding scope and report if:

- data is insufficient for the proposed model;
- reliability labels are too sparse;
- a requested metric cannot be obtained from available sources;
- a simpler method already satisfies the current gate;
- an optional feature threatens the 8-week project timeline;
- the proposed work would contaminate the test set;
- an unresolved architectural ambiguity affects research validity.

When stopped, provide evidence, the smallest safe fallback, and the exact decision required from the human lead.

## Completion Report

Every completed task must report:

- files changed;
- behavior changed;
- tests executed and results;
- experiments executed and IDs;
- assumptions;
- known limitations;
- remaining blockers;
- current gate status.

Never say “done” without verification.
