# Documentation Index

This repository uses **docs-as-code**: architectural, data, ML, and evaluation decisions are documented in version control and reviewed with code changes.

## Core Documents

- `project_requirements.md` — stable project requirements, requirement disposition, acceptance evidence, and scope-change rules.
- `architecture.md` — system boundaries, components, data flow, and non-goals.
- `raw_data_contract.md` — immutable collector artifact manifest, integrity, identity, and evolution rules.
- `data_schema.md` — raw/normalized execution data contract.
- `feature_schema.md` — feature availability, units, lineage, and leakage rules.
- `benchmark_plan.md` — reproducible workload/config experiment design.
- `evaluation_protocol.md` — baselines, split strategy, metrics, test freeze, and final acceptance rules.
- `engineering_standards.md` — repository conventions, versioning, configuration, logging, dependency discipline.
- `metric_catalog.md` — canonical metric definitions and formulas.
- `recommendation_policy.md` — hard constraints, Pareto stage, guardrails, and no-safe-recommendation behavior.
- `testing_strategy.md` — unit/contract/integration/model/optimizer/E2E testing.
- `security_and_operations.md` — secrets, access control, log sensitivity, and safe cluster interaction.
- `DATASET_CARD_TEMPLATE.md` / `MODEL_CARD_TEMPLATE.md` — reviewable dataset/model lineage and limitations.
- `source_references.md` — primary official technical references.

## Phase Contracts

`phases/` contains the scope, required artifacts, forbidden work, and Research Gate for each phase.

## Research Operations

- `experiments/EXPERIMENT_TEMPLATE.md` — one record per benchmark/model experiment.
- `adr/ADR_TEMPLATE.md` — architecture/research decision record template.
- `adr/ADR-0001-mvp-runtime-and-scope.md` — approved Spark-on-YARN runtime and MVP operational boundaries.
- `adr/ADR-0002-parallel-sql-boundary.md` — approved within-application SQL concurrency boundary.

## Documentation Rules

1. If code changes a schema, update its contract in the same change.
2. If a model input changes, update `feature_schema.md` and repeat leakage review.
3. If evaluation protocol changes after the test set is frozen, create an ADR and explain why.
4. If an assumption becomes false, update `PROJECT_STATE.md` immediately.
5. Do not store secrets, tokens, internal hostnames, or sensitive SQL/data paths in docs intended for sharing.
