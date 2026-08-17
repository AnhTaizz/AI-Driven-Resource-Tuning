# Phase 8 — Demo, Documentation, and Final Report

## Objective

Present the research system clearly, reproducibly, and without overstating model predictions or production readiness.

## Demo Capabilities

The user should be able to:

1. select an existing execution/job family or provide supported new-job inputs;
2. inspect historical characteristics;
3. view prior/current resource configuration;
4. request a recommendation;
5. see valid recommended resources;
6. compare against current/baseline;
7. inspect predicted runtime, derived resource cost, and risk;
8. read an evidence-based explanation;
9. understand when the system cannot safely recommend.

## UI Labeling

Clearly distinguish:

- OBSERVED;
- DERIVED;
- PREDICTED;
- RECOMMENDED.

Do not display “Resource saved 20%” as actual unless it comes from observed validation. For a not-yet-run candidate, use “predicted/estimated saving”.

## Documentation Deliverables

- deployment/setup guide;
- Spark History Server/YARN connection guide;
- dataset/benchmark generation guide;
- model train/retrain guide;
- evaluation methodology;
- known limitations;
- future work.

## Stretch Goals Only After Core Completion

- rule-based real-time warning;
- richer dashboard;
- automated retraining;
- scheduler integration.

The core demo/documentation must show the approved offline/manual feedback procedure and post-run diagnostic warnings. It must not label either as automated retraining or live monitoring.

## Final Gate

The project is ready for presentation only if:

- [ ] demo smoke test passes;
- [ ] README/setup path works from a clean environment or documented reproducible environment;
- [ ] source/docs/results agree on metric definitions;
- [ ] final claims are backed by experiment evidence;
- [ ] limitations are explicit;
- [ ] optional features did not replace real validation.
