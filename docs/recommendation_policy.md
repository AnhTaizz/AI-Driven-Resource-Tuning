# Recommendation Policy

## 1. Purpose

The model predicts candidate outcomes. The recommendation policy decides which candidate is acceptable. This policy is a research/business decision and must be explicit, versioned, and human-approved.

## 2. Hard Constraints

A candidate must be rejected before scoring/recommendation if it violates any approved constraint, for example:

- executor count outside supported range;
- cores/executor outside supported range;
- executor memory outside supported range;
- queue/cluster cap exceeded;
- unsupported dynamic-allocation combination;
- known organization-specific Spark/YARN constraints.

For the approved MVP, reject dynamic-allocation candidates. Static allocation is the only supported recommendation mode; collected dynamic-allocation executions are analysis evidence only.

## 3. Candidate Objectives

Typical objectives:

- lower predicted runtime;
- lower derived resource cost;
- lower reliability risk.

No single objective should silently dominate unless policy says so.

## 4. Pareto Stage

A candidate is dominated if another valid candidate is no worse on all chosen objectives and strictly better on at least one.

The optimizer may remove dominated candidates before final selection.

## 5. Final Selection Policy

The exact production/research threshold is **TBD until human approval**.

Recommended configurable form:

```text
Choose the minimum-resource candidate among safe Pareto candidates
subject to:
  predicted_runtime <= reference_runtime * (1 + runtime_guardrail)
  risk <= approved_risk_threshold
```

Possible reference runtime:

- current/default config predicted runtime;
- fastest safe candidate predicted runtime;
- approved SLA/target runtime.

Do not change the reference silently across experiments.

## 6. Confidence / Coverage Guard

Return `NO_SAFE_RECOMMENDATION` rather than extrapolating aggressively when:

- required features are missing;
- workload is far outside training coverage;
- no valid candidate satisfies hard constraints;
- model/risk estimator indicates unacceptable uncertainty according to the approved rule.

A baseline fallback may be returned separately as `fallback_config`, but it must not be mislabeled as ML recommendation.

## 7. Policy Versioning

Every recommendation should record:

- policy version;
- candidate-space version;
- model version;
- feature-set version;
- reference config;
- guardrail values;
- selected candidate and Pareto set summary.
