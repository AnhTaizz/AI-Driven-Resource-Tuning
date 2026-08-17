# ADR-0001 — MVP Runtime Environment and Operational Scope

- Status: Accepted
- Date: 2026-08-16
- Decision owners: Human Tech Lead/Researcher

## Context

The MVP needs reproducible Spark/YARN evidence without depending on unavailable company production history. Collector behavior, resource accounting, and validation all depend on the actual deployment mode and runtime versions. Live monitoring, dynamic allocation, and automated retraining would introduce different data and evaluation contracts that do not fit the initial eight-week scope.

## Decision Drivers

- research validity;
- reproducibility;
- compatibility with the Spark History Server and YARN ResourceManager requirements;
- feasible delivery within eight weeks;
- clear separation between observed benchmark evidence and production claims.

## Options Considered

### Spark local/standalone benchmark

Pros:

- simpler environment setup;
- fast local iteration.

Cons:

- cannot validate YARN collection and allocation metrics end to end;
- does not represent the Hadoop/YARN deployment boundary in the project brief.

### Synthetic workloads executed on Spark-on-YARN

Pros:

- exercises History Server/event-log and YARN collection paths;
- supports traceable observed allocation metrics;
- keeps workload generation controllable and reproducible.

Cons:

- higher environment setup cost;
- benchmark results remain environment-specific and are not company production evidence.

## Decision

The MVP will use synthetic benchmark workloads executed on **Spark-on-YARN**.

- Collector compatibility family: Apache Spark 3.5.x and Hadoop/YARN 3.3.x.
- The deployable environment, not documentation aliases such as `latest` or `stable`, is the version source of truth.
- Before version-sensitive parser behavior is implemented or frozen, record the exact Spark, Hadoop/YARN, Java, Python, deployment image/distribution, and relevant configuration versions as `benchmark_environment_id` metadata.
- Static allocation is the supported MVP recommendation mode. Dynamic-allocation executions may be collected for evidence, but they are not valid recommendation candidates until a separately approved contract exists.
- The feedback loop is offline/manual: collect new executions, rebuild/version the dataset, retrain explicitly, validate, and promote a new model version.
- Resource-waste/shortage warnings are post-run diagnostics in the MVP. Live running-job warning is a stretch goal.
- The demo is recommendation-only and does not submit or modify production jobs automatically.

## Consequences

Positive:

- Phase 1 can validate both Spark and YARN sources against one reproducible environment;
- resource and runtime claims remain tied to observed benchmark executions;
- feature and cost semantics avoid dynamic-allocation ambiguity in the MVP;
- feedback and warning behavior have testable boundaries.

Negative/trade-offs:

- conclusions do not automatically generalize to company production clusters;
- dynamic allocation, live warnings, and automated retraining are outside the MVP;
- exact patch versions remain an environment-verification task until the benchmark runtime is deployed.

## Validation / Revisit Trigger

Revisit this decision if the benchmark cannot run on YARN, an authorized production environment becomes the primary source, or dynamic allocation is required before the Feature Gate. Such a change must update collection fixtures, cost accounting, evaluation, and recommendation constraints.
