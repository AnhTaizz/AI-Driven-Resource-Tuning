# Documentation Index

This repository uses **docs-as-code**: architectural, data, ML, and evaluation decisions are documented in version control and reviewed with code changes.

## Core Documents

- `project_requirements.md` — stable project requirements, requirement disposition, acceptance evidence, and scope-change rules.
- `architecture.md` — system boundaries, components, data flow, and non-goals.
- `benchmark_environment.md` — planned and verified local Spark-on-YARN topology, capacity snapshot, and limitations.
- `local_yarn_v1_human_review_packet.md` — evidence review and the 2026-08-25 Human Tech Lead decision verifying the exact `LOCAL_YARN_V1` session/snapshot.
- `phase_1_contract_consolidation_review_packet.md` — pending Human decisions for repository/evidence durability and unresolved Phase 1 execution, target, temporal, family, metric, concurrency, and diagnostic semantics.
- `benchmark_data_spec.md` — TPC-DS-based generation, raw/materialized lineage, selected tables, and dataset identity.
- `workload_catalog.md` — planned versioned Spark workload definitions and controlled settings; no workload is implemented yet.
- `raw_data_contract.md` — immutable collector artifact manifest, integrity, identity, and evolution rules.
- `data_schema.md` — raw/normalized execution data contract.
- `feature_schema.md` — feature availability, units, lineage, and leakage rules.
- `benchmark_plan.md` — reproducible workload/config experiment design.
- `tpcds_implementation_plan.md` — read-only toolkit audit, licensing/hygiene concerns, integration options, and independently reviewed future steps.
- `tpcds_toolkit_integration_review_packet.md` — P04A toolkit provenance/licensing/hygiene audit, option comparison, proposed strategy, and P04B decision contract; pending Human decision.
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

- `experiments/EXPERIMENT_TEMPLATE.md` — one record per benchmark/model experiment, including dataset/workload/environment lineage and host-quality observations.
- `adr/ADR_TEMPLATE.md` — architecture/research decision record template.
- `adr/ADR-0001-mvp-runtime-and-scope.md` — approved Spark-on-YARN runtime and MVP operational boundaries.
- `adr/ADR-0002-parallel-sql-boundary.md` — approved within-application SQL concurrency boundary.
- `adr/ADR-0003-local-benchmark-environment-and-bootstrap.md` — approved local benchmark subsystem, bootstrap, and transfer boundary.
- `adr/ADR-0004-adopt-tpc-ds-as-controlled-benchmark-foundation.md` — approved migration from the custom ecommerce foundation to a non-official TPC-DS-based controlled benchmark. ADR-0003 remains unchanged historical evidence; ADR-0004 supersedes only its old dataset/workload foundation and identifiers.

## Documentation Rules

1. If code changes a schema, update its contract in the same change.
2. If a model input changes, update `feature_schema.md` and repeat leakage review.
3. If evaluation protocol changes after the test set is frozen, create an ADR and explain why.
4. If an assumption becomes false, update `PROJECT_STATE.md` immediately.
5. Do not store secrets, tokens, internal hostnames, or sensitive SQL/data paths in docs intended for sharing.
