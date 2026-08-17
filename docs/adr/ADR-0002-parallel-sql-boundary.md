# ADR-0002 — Parallel SQL Execution Boundary

- Status: Accepted
- Date: 2026-08-16
- Decision owners: Human Tech Lead/Researcher

## Context

The project brief requires aggregate resource estimation for jobs with multiple SQL nodes running in parallel. This could mean overlapping Spark SQL executions or stages inside one Spark application, or multiple Spark applications inside an external workflow. These interpretations require different identifiers, sources, aggregation, and validation.

## Decision Drivers

- preserve one Spark application execution as the canonical modeling unit;
- match Spark/YARN resource allocation boundaries;
- avoid double-counting overlapping runtime and resources;
- keep the MVP independent of a workflow orchestrator.

## Options Considered

### Multiple applications in one external workflow

Pros:

- represents workflow-level capacity planning.

Cons:

- requires a workflow identifier and orchestrator data source;
- changes the canonical observation unit and recommendation target;
- is not reliably recoverable from Spark/YARN application data alone.

### Overlapping SQL executions/stages inside one Spark application

Pros:

- preserves the application execution as the resource/recommendation unit;
- can be reconstructed where supported from Spark event-log/SQL/stage timing evidence;
- aligns executor allocation with the enclosing Spark application.

Cons:

- SQL execution identifiers or timing may be missing for some workloads;
- overlap aggregation requires interval-based logic and explicit missingness.

## Decision

For the MVP, “parallel SQL nodes” means **Spark SQL executions and/or stages whose execution intervals overlap within one Spark application execution**.

- The canonical modeling unit remains one Spark application execution.
- Preserve `sql_execution_id`, stage membership, start/end timestamps, and parent application identity where the source exposes them.
- Determine concurrency using interval overlap; never sum stage or SQL runtimes to estimate application wall-clock runtime.
- Attribute observed resource allocation at application/executor/YARN-container level. SQL/stage records describe workload structure and concurrency, not independent resource allocations unless a validated attribution method is later approved.
- Multiple Spark applications belonging to one workflow are outside the MVP and must not be inferred from application names alone.
- If SQL timing/membership is unavailable, record explicit missingness and do not fabricate concurrency features.

## Consequences

Positive:

- the data contract retains stable Spark/YARN identities;
- concurrency features can be derived deterministically without double-counting wall time;
- the MVP does not need Airflow/Oozie or other workflow metadata.

Negative/trade-offs:

- the system does not recommend aggregate resources for multi-application workflows;
- SQL concurrency coverage depends on event-log/source capability.

## Validation / Revisit Trigger

Revisit if the mentor confirms that “SQL nodes” means multiple Spark applications in a workflow. That change requires a new workflow-level schema, source integration, split strategy, cost boundary, and validation protocol.
