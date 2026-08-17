# Phase 0 — Problem Definition and Architecture

## Objective

Freeze the research problem, system boundaries, data assumptions, baseline strategy, and evaluation design before implementation expands.

## Required Inputs

- project brief;
- current repository, if any;
- target environment constraints;
- available Spark/YARN versions and access information, if known.

## Required Outputs

- problem definition;
- research questions;
- architecture diagram/data flow;
- first data schema draft;
- ML problem formulation;
- baseline plan;
- evaluation protocol draft;
- risk register;
- explicit unknowns/TBDs;
- proposed phased plan.

## Forbidden Work

- production implementation;
- final model training;
- silently choosing unavailable metrics;
- treating speculative assumptions as facts.

## Agent Task Contract

```text
Read the project brief and repository.
Do not write implementation code yet.

Produce:
1. problem definition
2. research questions
3. architecture
4. data flow
5. data schema draft
6. ML formulation
7. baseline methods
8. evaluation method
9. risks and unknowns
10. phase plan

For every major decision:
- state evidence/assumption
- compare alternatives
- explain trade-offs
- explain research impact

Mark all unverified facts as TBD.
```

## Gate — Human Approval Required

Pass only when the human lead approves:

- the unit of observation;
- the primary research question;
- the core architecture;
- primary model target;
- baseline requirement;
- evaluation strategy;
- explicit non-goals.
