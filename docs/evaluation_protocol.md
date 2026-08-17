# Evaluation Protocol

## 1. Research Question

Does the recommendation system reduce Spark resource consumption while keeping runtime and reliability within an acceptable trade-off compared with meaningful baselines?

## 2. Baselines

Required:

1. **Current/default** — configuration currently used or benchmark default.
2. **Nearest historical/similar-job** — choose a config from prior similar executions using an explicit distance definition.
3. **Simple heuristic** — transparent workload/resource rules.
4. **ML + optimization recommendation** — proposed system.

Optional secondary comparison:

- direct config regression.

## 3. Evaluation Tracks and Dataset Splits

The MVP reports two distinct use cases. Their results must not be merged into one unlabeled aggregate.

### Track A — Known-workload next-run recommendation (primary)

Evaluate later executions/configurations of workload families that have strictly earlier history.

- split by time within each eligible `job_family_id`;
- compute historical features using only executions before each row's `as_of_timestamp`;
- keep repeated executions/configurations for a target run out of its training/history cutoff;
- use this track for the primary history-aware recommendation claim.

### Track B — Unseen-workload robustness (secondary)

Hold out entire workload families with a group split.

- no target-family history is available;
- retrieval/index fitting uses only the training-family corpus;
- use only legitimate pre-run descriptors and training-corpus similarity evidence;
- report coverage failures and `NO_SAFE_RECOMMENDATION` behavior;
- do not present Track B as equivalent to a known workload with history.

### Validation and test freeze

Use separate training, validation, and frozen test identities for each track. Hyperparameters, thresholds, candidate policy, and preprocessing are selected without final-test outcomes. Document the exact time/group rules, seeds where applicable, and all frozen IDs before model tuning.

## 4. Prediction Metrics

For runtime regression:

- MAE;
- MAPE, with documented handling of very small targets;
- RMSE;
- R² as a secondary descriptive metric.

Report metrics globally and by workload group/scale. Do not rely on a single aggregate score.

Report Track A and Track B separately. A model may be acceptable for known workloads while unsupported for unseen families.

## 5. Decision Metrics

Primary decision metrics:

```text
runtime_change_pct
= (recommended_runtime - baseline_runtime) / baseline_runtime * 100

resource_saving_pct
= (baseline_resource_cost - recommended_resource_cost) / baseline_resource_cost * 100
```

Resource-cost measures should include at least one of:

- executor-hours;
- memory-GB-hours;
- vcore-hours;
- a YARN-derived aggregate allocation measure if available and validated.

Reliability measures:

- failure rate;
- OOM incidence;
- memory/disk spill behavior.

Recommendation quality where the candidate space has observed runs:

- regret relative to best observed feasible candidate;
- Pareto efficiency;
- rank correlation or top-k hit rate, if useful.

## 6. Recommendation Guardrails

Do not hardcode a business trade-off without approval.

The project should configure a policy such as:

```text
minimize resource cost
subject to:
  predicted runtime <= baseline_runtime * (1 + approved_runtime_guardrail)
  reliability risk <= approved threshold
  cluster constraints satisfied
```

The runtime guardrail is a research/business parameter and must be recorded in `PROJECT_STATE.md` once approved.

## 7. Real Validation

Offline prediction metrics are not enough. Final claims require actual Spark executions on frozen hold-out workloads.

For each test case:

- run baseline/current config;
- run heuristic config where feasible;
- run ML recommendation;
- capture observed runtime/resource/reliability;
- repeat when budget allows;
- report every valid result, including losses.

Do not tune the model or policy on the final test cases after seeing their results.

## 8. Statistical/Operational Noise

Report variability across repeated runs. If sample size is too small for formal significance tests, do not imply statistical certainty. Show raw/summary measurements and discuss cluster noise explicitly.

## 9. Acceptance Criteria

A phase/model does not pass simply because MAE/R² looks good.

Minimum final evidence:

- baseline comparison exists;
- real Spark recommended configs were executed;
- resource and runtime deltas are based on observed values;
- reliability is not materially degraded without disclosure;
- failure cases/edge cases are included;
- limitations for unseen job families are stated.

## 10. Official Method References

- scikit-learn GroupKFold: https://scikit-learn.org/stable/modules/generated/sklearn.model_selection.GroupKFold.html
- scikit-learn TimeSeriesSplit: https://scikit-learn.org/stable/modules/generated/sklearn.model_selection.TimeSeriesSplit.html
