# Engineering Standards

## 1. Repository Principles

Prefer a modular monolith with explicit packages rather than premature services.

Suggested shape:

```text
src/
  collection/
  normalization/
  features/
  datasets/
  baselines/
  modeling/
  optimization/
  recommendation/
  serving/
  common/

tests/
  unit/
  contract/
  integration/
  e2e/
```

## 2. Configuration

- No secrets or environment-specific hosts in source code.
- Use config files/environment variables with documented precedence.
- Separate research/model configuration from deployment configuration.
- Every experiment must persist the effective resolved config.

Recommended categories:

- source endpoints/timeouts;
- data paths;
- feature-set version;
- model hyperparameters;
- candidate-space constraints;
- recommendation policy;
- experiment seed.

## 3. Dependency Discipline

Before adding a dependency, document:

- what problem it solves;
- why standard library/current dependencies are insufficient;
- operational/reproducibility cost;
- license/security considerations if relevant.

Do not add MLflow/DVC/Optuna/etc. merely because they are “enterprise tools”. Use them only if their value exceeds setup cost for the 8-week project.

## 4. Logging

Use structured logs with fields such as:

- `event`
- `execution_id`
- `spark_application_id`
- `experiment_id`
- `component`
- `duration_ms`
- `status`
- `error_type`

Never log secrets. Avoid dumping entire raw payloads to application logs; persist raw data in the designated raw store instead.

## 5. Errors

Differentiate:

- validation/schema errors;
- source unavailable/transient errors;
- authorization errors;
- unsupported version/parser errors;
- insufficient-data/recommendation errors.

Do not catch broad exceptions and silently continue with fabricated defaults.

## 6. Types and Units

- use canonical units internally (`bytes`, `milliseconds`, timestamps in UTC);
- convert at boundaries/UI only;
- encode unit in name where ambiguity is likely;
- avoid floats for byte counts and timestamps when integers are sufficient.

## 7. Reproducibility

Persist:

- code revision;
- Python/package environment lock or export;
- dataset version;
- feature-set version;
- model config;
- random seed;
- benchmark config.

MLflow may be introduced for experiment tracking if the team needs run comparison/lineage and setup remains lightweight; local tracking is sufficient for the prototype.

## 8. Documentation and Decisions

Create an ADR when changing:

- major component boundaries;
- canonical schema meaning;
- feature availability policy;
- split/evaluation protocol;
- primary model formulation;
- recommendation objective/guardrail.

Use `docs/adr/ADR_TEMPLATE.md`.

## 9. Definition of Done

A change is complete only when:

- implementation is scoped;
- tests pass;
- docs/contracts are updated;
- experiment/output is inspected;
- assumptions and limitations are recorded;
- no unrelated files are modified.
