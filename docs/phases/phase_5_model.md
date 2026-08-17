# Phase 5 — Performance Model

## Objective

Train a reproducible runtime predictor that is accurate enough to support candidate ranking and recommendation decisions.

## MVP Target

Required:

- runtime regression.

Optional:

- OOM/failure/spill risk only if label volume/quality is sufficient.

## Candidate Models

Start with explainable tree-based models:

- Random Forest;
- one gradient-boosted tree implementation.

Avoid deep learning unless simpler models demonstrably fail and enough data exists.

## Required Outputs

- reproducible training pipeline;
- frozen feature-set version;
- model configs;
- validation report;
- workload-group error analysis;
- feature importance/interpretation;
- serialized model;
- model version metadata.

## Agent Task Contract

```text
Train runtime models using only the approved training/validation protocol.

Requirements:
- pipeline preprocessing with the estimator
- fixed seed where applicable
- no final test-set tuning
- compare at least a simple tree ensemble and one boosting model
- log parameters, metrics, dataset/feature versions
- report MAE/MAPE/RMSE/R2 by relevant workload groups
- inspect whether ranking quality is usable for candidate search

If reliability labels are sparse, stop and use a documented rule-based risk estimator instead of forcing a classifier.
```

## Model Gate — PASS if

- [ ] No leakage is detected.
- [ ] Validation metrics/error analysis exist.
- [ ] Model artifact can be reloaded and used for inference.
- [ ] Model coverage/failure regions are documented.
- [ ] Candidate-ranking usefulness is assessed, not just R².
- [ ] Final test set has not been used for tuning.
