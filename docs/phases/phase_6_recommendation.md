# Phase 6 — Candidate Search and Recommendation

## Objective

Turn the performance model into a valid multi-objective resource recommendation system.

## Layers

1. candidate generation;
2. hard constraint validation;
3. performance/risk prediction;
4. derived resource cost;
5. Pareto/multi-objective comparison;
6. final recommendation policy;
7. evidence-based explanation.

## Candidate Constraints

Examples, to be configured from the environment:

- valid executor count range;
- valid cores/executor range;
- valid memory range;
- queue/cluster resource caps;
- dynamic allocation compatibility;
- organization-specific Spark limits.

## Agent Task Contract

```text
Implement candidate search and recommendation without changing the approved evaluation protocol.

For each valid candidate:
- predict runtime
- estimate reliability risk if available
- derive resource cost

Then:
- remove invalid candidates
- compute Pareto-efficient set where appropriate
- apply the approved recommendation policy
- return NO_SAFE_RECOMMENDATION if constraints cannot be satisfied

Keep Prediction, Optimization, and Recommendation as separate modules.

Output:
- recommended config
- predicted runtime
- derived resource cost
- risk estimate
- baseline/current comparison
- evidence-backed explanation
```

## Recommendation Gate — PASS if

- [ ] Invalid configs cannot be recommended.
- [ ] Cluster constraints are tested.
- [ ] Pareto dominance logic is tested.
- [ ] Policy is explicit/versioned.
- [ ] Same input/model/policy gives deterministic recommendation.
- [ ] Explanation uses actual features/history/predictions.
- [ ] No-safe-recommendation path exists.
